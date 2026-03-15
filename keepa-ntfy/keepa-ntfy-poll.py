#!/usr/bin/env python3
"""
keepa-ntfy-poll.py
Pollt Outlook (via OAuth2-Proxy) per IMAP auf Keepa-Preisalarme
und pusht sie als Notification an ntfy.

Laeuft als systemd-Timer im ntfy LXC.
"""

import imaplib
import email
import email.header
import re
import json
import urllib.request
import urllib.error
import ssl
import sys
import os
import logging
from datetime import datetime
from email.utils import parseaddr
from pathlib import Path

# ──────────────────────────────────────────────
# Konfiguration
# ──────────────────────────────────────────────
IMAP_HOST     = os.getenv("IMAP_HOST", "oauth.home.intern")
IMAP_PORT     = int(os.getenv("IMAP_PORT", "1993"))
IMAP_USER     = os.getenv("IMAP_USER", "DEINE-MAIL-ADRESSE")
IMAP_PASS     = os.getenv("IMAP_PASS", "")  # Aus Environment oder .env

NTFY_URL      = os.getenv("NTFY_URL", "https://ntfy.home.intern")
NTFY_TOPIC    = os.getenv("NTFY_TOPIC", "keepa")
NTFY_TOKEN    = os.getenv("NTFY_TOKEN", "")  # Bearer Token

# Keepa Absender-Adressen (werden case-insensitive geprueft)
KEEPA_SENDERS = ["pricealert@keepa.com", "noreply@keepa.com", "alerts@keepa.com"]

# Statefile: speichert UIDs bereits verarbeiteter Mails
STATE_FILE    = Path(os.getenv("STATE_FILE", "/var/lib/keepa-ntfy/processed_uids.json"))

# Logging
LOG_LEVEL     = os.getenv("LOG_LEVEL", "INFO")

# ──────────────────────────────────────────────
# Logging Setup
# ──────────────────────────────────────────────
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL.upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("keepa-ntfy")


def load_processed_uids() -> set:
    """Laedt bereits verarbeitete Mail-UIDs aus dem State-File."""
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text())
            return set(data.get("uids", []))
        except (json.JSONDecodeError, KeyError):
            log.warning("State-File korrupt, starte mit leerem State")
    return set()


def save_processed_uids(uids: set):
    """Speichert verarbeitete UIDs ins State-File."""
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps({
        "uids": list(uids),
        "updated": datetime.now().isoformat(),
    }, indent=2))


def decode_header_value(raw: str) -> str:
    """Dekodiert MIME-encoded Header (z.B. UTF-8 Subject)."""
    parts = email.header.decode_header(raw)
    decoded = []
    for part, charset in parts:
        if isinstance(part, bytes):
            decoded.append(part.decode(charset or "utf-8", errors="replace"))
        else:
            decoded.append(part)
    return " ".join(decoded)


def get_html_body(msg: email.message.Message) -> str | None:
    """Extrahiert den HTML-Body aus einer E-Mail."""
    for part in msg.walk():
        if part.get_content_type() != "text/html":
            continue
        payload = part.get_payload(decode=True)
        if not payload:
            continue
        charset = part.get_content_charset() or "utf-8"
        return payload.decode(charset, errors="replace")
    return None


def parse_keepa_html(html: str) -> dict:
    """Parst die Keepa-Mail und extrahiert die wesentlichen Elemente."""
    import html as html_mod
    data = {}

    # 1. Produktbild (Amazon)
    m = re.search(r'src="(https://m\.media-amazon\.com/images/[^"]+)"', html)
    if m:
        data["product_image"] = html_mod.unescape(m.group(1))

    # 2. Preisgraph (Keepa)
    m = re.search(r'src="(https://graph\.keepa\.com/[^"]+)"', html)
    if m:
        data["price_graph"] = html_mod.unescape(m.group(1))

    # 3. Amazon-Link (Keepa redirect)
    m = re.search(r'href="(https://dyn[^"]*keepa\.com/r/[^"]+)"', html)
    if m:
        data["amazon_link"] = html_mod.unescape(m.group(1))

    # 4. Produktname (Text im Link zum Produkt)
    m = re.search(
        r'href="https://dyn[^"]*keepa\.com/r/[^"]*"[^>]*>([^<]+)</a>',
        html,
    )
    if m:
        data["product_name"] = html_mod.unescape(m.group(1)).strip()

    # 5. Preistabelle: Aktuell, Wunsch, Differenz
    # Zeilen aus <tbody> parsen — jede Zeile hat: Typ, Aktuell, Wunsch, Differenz, Ursache
    row_pattern = re.compile(
        r'<tr>\s*'
        r'<td[^>]*>([^<]*)</td>\s*'           # Typ (z.B. "Amazon")
        r'<td[^>]*>([^<]*)</td>\s*'            # Aktuell
        r'<td[^>]*>([^<]*)</td>\s*'            # Wunsch
        r'<td[^>]*>(?:<[^>]*>)*([^<]*)(?:</[^>]*>)*</td>\s*'  # Differenz (ggf. in <span>)
        r'<td[^>]*>([^<]*)</td>',              # Ursache
        re.DOTALL,
    )
    rows = []
    for rm in row_pattern.finditer(html):
        row = {
            "typ": html_mod.unescape(rm.group(1)).strip(),
            "aktuell": html_mod.unescape(rm.group(2)).replace("\xa0", " ").strip(),
            "wunsch": html_mod.unescape(rm.group(3)).replace("\xa0", " ").strip(),
            "differenz": html_mod.unescape(rm.group(4)).replace("\xa0", " ").strip(),
        }
        rows.append(row)
    if rows:
        data["price_rows"] = rows

    return data


def build_markdown(data: dict, title: str = "") -> str:
    """Baut den Markdown-Body fuer ntfy aus den extrahierten Daten."""
    parts = []

    # Produktbild
    if "product_image" in data:
        parts.append(f"![Produkt]({data['product_image']})")
        parts.append("")

    # Produktname als Link (Linktext = Titel)
    if "amazon_link" in data:
        link_text = title or data.get("product_name", "Ab zu Amazon!")
        parts.append(f"**[{link_text}]({data['amazon_link']})**")
        parts.append("")

    # Preisinfo
    if "price_rows" in data:
        for row in data["price_rows"]:
            parts.append(f"- **Aktuell:** {row['aktuell']}")
            parts.append(f"- **Wunsch:** {row['wunsch']}")
            parts.append(f"- **Differenz:** {row['differenz']}")
        parts.append("")

    # Preisgraph
    if "price_graph" in data:
        parts.append(f"![Preisverlauf]({data['price_graph']})")

    return "\n".join(parts)


def build_title(data: dict, max_len: int = 60) -> str:
    """Baut einen kompakten Titel: Produktname.. [Aktuell] -> [Wunsch]"""
    name = data.get("product_name", "Keepa Alert")
    suffix = ""
    if "price_rows" in data and data["price_rows"]:
        row = data["price_rows"][0]
        # Preise in deutsches Format: "40.50 €"
        aktuell = row['aktuell'].replace('€', '').replace('\xa0', '').strip() + ' €'
        wunsch = row['wunsch'].replace('€', '').replace('\xa0', '').strip() + ' €'
        suffix = f" {aktuell} → {wunsch}"

    # Produktname kuerzen, sodass Titel + Suffix in max_len passt
    name_budget = max_len - len(suffix)
    if name_budget < 10:
        name_budget = 10
    if len(name) > name_budget:
        name = name[: name_budget - 2].rstrip(" -,") + ".."

    return f"{name}{suffix}"


def strip_emojis(text: str) -> str:
    """Entfernt Emojis und Unicode-Symbole aus dem Betreff."""
    emoji_pattern = re.compile(
        "["
        "\U0001F600-\U0001F64F\U0001F300-\U0001F5FF\U0001F680-\U0001F6FF"
        "\U0001F1E0-\U0001F1FF\U00002702-\U000027BF\U0000FE00-\U0000FE0F"
        "\U0000200D\U00002640-\U00002642\U00002300-\U000023FF"
        "\U00010000-\U0001FFFF"
        "]+",
        flags=re.UNICODE,
    )
    return emoji_pattern.sub("", text).strip()


def send_ntfy(title: str, md_body: str, click_url: str | None = None):
    """Sendet eine Markdown-Notification an ntfy."""
    url = f"{NTFY_URL.rstrip('/')}/{NTFY_TOPIC}"
    headers = {
        "Title": title.encode("utf-8"),
        "Priority": "high",
        "Markdown": "yes",
    }
    if NTFY_TOKEN:
        headers["Authorization"] = f"Bearer {NTFY_TOKEN}"
    if click_url:
        headers["Click"] = click_url

    body = md_body[:4000].encode("utf-8")

    req = urllib.request.Request(url, data=body, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            log.info(f"ntfy gesendet (HTTP {resp.status}): {title[:60]}")
    except urllib.error.HTTPError as e:
        log.error(f"ntfy HTTP-Fehler {e.code}: {e.read().decode(errors='replace')}")
    except urllib.error.URLError as e:
        log.error(f"ntfy Verbindungsfehler: {e.reason}")


def poll_keepa_mails():
    """Hauptlogik: IMAP verbinden, Keepa-Mails suchen, an ntfy senden."""
    processed = load_processed_uids()
    new_processed = set()

    log.info(f"Verbinde zu IMAP {IMAP_HOST}:{IMAP_PORT} ...")

    # Proxy ist lokal im VLAN, kein SSL noetig
    try:
        imap = imaplib.IMAP4(IMAP_HOST, IMAP_PORT)
    except Exception as e:
        log.error(f"IMAP-Verbindung fehlgeschlagen: {e}")
        sys.exit(1)

    try:
        imap.login(IMAP_USER, IMAP_PASS)
        log.info("IMAP Login erfolgreich")
    except imaplib.IMAP4.error as e:
        log.error(f"IMAP Login fehlgeschlagen: {e}")
        imap.logout()
        sys.exit(1)

    try:
        imap.select("INBOX", readonly=False)

        # Suche nach ungelesenen Mails
        status, data = imap.uid("SEARCH", None, "UNSEEN")
        if status != "OK":
            log.warning(f"IMAP SEARCH fehlgeschlagen: {status}")
            return

        uids = data[0].split() if data[0] else []
        log.info(f"{len(uids)} ungelesene Mail(s) gefunden")

        keepa_count = 0

        for uid_bytes in uids:
            uid = uid_bytes.decode()

            # Skip bereits verarbeitete
            if uid in processed:
                continue

            # Mail-Header holen (effizient, nicht ganzer Body)
            status, header_data = imap.uid("FETCH", uid, "(BODY.PEEK[HEADER.FIELDS (FROM SUBJECT)])")
            if status != "OK":
                continue

            raw_header = header_data[0][1]
            header_msg = email.message_from_bytes(raw_header)

            from_addr = parseaddr(header_msg.get("From", ""))[1].lower()

            # Nur Keepa-Mails verarbeiten
            if not any(sender in from_addr for sender in KEEPA_SENDERS):
                continue

            log.debug(f"Keepa-Mail gefunden: UID {uid}, From: {from_addr}")

            # Jetzt ganzen Body holen
            status, msg_data = imap.uid("FETCH", uid, "(RFC822)")
            if status != "OK":
                continue

            msg = email.message_from_bytes(msg_data[0][1])

            # HTML parsen und Markdown aufbauen
            html_body = get_html_body(msg)
            if html_body:
                data = parse_keepa_html(html_body)
                title = build_title(data)
                md_body = build_markdown(data, title=title)
            else:
                md_body = "(Kein HTML-Inhalt)"
                data = {}
                title = decode_header_value(msg.get("Subject", "Keepa Alert"))

            log.debug(f"Extrahiert: {list(data.keys())}")

            # An ntfy senden
            send_ntfy(
                title=title,
                md_body=md_body,
                click_url=data.get("amazon_link"),
            )

            # Mail als gelesen markieren
            imap.uid("STORE", uid, "+FLAGS", "\\Seen")
            new_processed.add(uid)
            keepa_count += 1

        log.info(f"{keepa_count} Keepa-Mail(s) verarbeitet")

    finally:
        imap.close()
        imap.logout()

    # State aktualisieren (alte UIDs behalten, neue hinzufuegen)
    # Maximal die letzten 500 UIDs behalten, um das File nicht wachsen zu lassen
    all_uids = processed | new_processed
    if len(all_uids) > 500:
        all_uids = set(sorted(all_uids, key=int, reverse=True)[:500])
    save_processed_uids(all_uids)


if __name__ == "__main__":
    log.info("=== keepa-ntfy-poll gestartet ===")
    poll_keepa_mails()
    log.info("=== keepa-ntfy-poll beendet ===")
