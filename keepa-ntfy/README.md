# Keepa → ntfy Bridge

Pollt per IMAP eine Mailbox auf [Keepa](https://keepa.com) Preisalarm-Mails und leitet sie als aufbereitete Push-Notification an eine selbstgehostete [ntfy](https://ntfy.sh)-Instanz weiter.

## Was es macht

1. Verbindet sich per IMAP mit einer Mailbox (z.B. über einen lokalen OAuth2-Proxy)
2. Sucht nach ungelesenen Mails von Keepa (`pricealert@keepa.com`)
3. Parst den HTML-Body und extrahiert:
   - Produktbild (Amazon)
   - Produktname + Amazon-Link
   - Preistabelle (Aktuell / Wunsch / Differenz)
   - Keepa-Preisverlauf-Graph
4. Baut daraus eine kompakte Markdown-Notification mit Inline-Bildern
5. Sendet sie per HTTP POST an ntfy
6. Markiert die Mail als gelesen und merkt sich die UID

Läuft als systemd-Timer (alle 5 Minuten).

## Voraussetzungen

- **ntfy** — selbstgehostete Instanz mit Token-Authentifizierung
- **IMAP-Zugang** zur Mailbox, in der Keepa-Alerts ankommen. Bei Microsoft/Outlook mit OAuth2 empfiehlt sich ein lokaler IMAP-Proxy wie [email-oauth2-proxy](https://github.com/simonrob/email-oauth2-proxy)
- **Python 3.10+** — keine externen Dependencies, nur Standardbibliothek
- **Keepa-Account** mit aktivierten E-Mail-Benachrichtigungen

## Dateien

```
keepa-ntfy-poll.py      # Hauptscript
keepa-ntfy.env          # Credentials / Konfiguration
keepa-ntfy.service      # systemd Oneshot Unit
keepa-ntfy.timer        # systemd Timer (5 Min)
```

## Installation

```bash
# Verzeichnisse anlegen
mkdir -p /opt/keepa-ntfy /etc/keepa-ntfy /var/lib/keepa-ntfy

# Dateien kopieren
cp keepa-ntfy-poll.py /opt/keepa-ntfy/
cp keepa-ntfy.env /etc/keepa-ntfy/
cp keepa-ntfy.service keepa-ntfy.timer /etc/systemd/system/

# Berechtigungen
chmod 600 /etc/keepa-ntfy/keepa-ntfy.env
chown nobody:nogroup /etc/keepa-ntfy/keepa-ntfy.env /var/lib/keepa-ntfy

# systemd laden
systemctl daemon-reload
```

## Konfiguration

Alle Einstellungen in `/etc/keepa-ntfy/keepa-ntfy.env` anpassen:

```env
# IMAP-Zugang (Mailbox mit Keepa-Alerts)
IMAP_HOST=oauth.home.intern         # IP des IMAP-Servers / OAuth2-Proxy
IMAP_PORT=1993                # Port (Standard: 993 für SSL, hier Proxy)
IMAP_USER=user@outlook.de     # Mailadresse
IMAP_PASS=dein-passwort        # Passwort / App-Password

# ntfy-Instanz
NTFY_URL=https://ntfy.home.intern
NTFY_TOPIC=keepa               # Topic-Name
NTFY_TOKEN=tk_DEIN_TOKEN        # Bearer Token

# Optional
STATE_FILE=/var/lib/keepa-ntfy/processed_uids.json
LOG_LEVEL=INFO                  # DEBUG für Fehlersuche
```

> **Hinweis:** Das Script verbindet sich standardmäßig per **Plain IMAP** (kein SSL), da es für die Nutzung hinter einem lokalen OAuth2-Proxy gedacht ist. Wer direkt gegen einen IMAP-Server mit SSL verbinden will, muss `imaplib.IMAP4` durch `imaplib.IMAP4_SSL` im Script ersetzen.

## Starten

```bash
# Einmalig testen
systemctl start keepa-ntfy.service
journalctl -u keepa-ntfy.service -e --no-pager

# Timer aktivieren (alle 5 Min)
systemctl enable --now keepa-ntfy.timer

# Timer prüfen
systemctl list-timers keepa-ntfy*
```

## Ergebnis

Die ntfy-Notification zeigt:

- **Titel:** `Kopp POWERversal 10-fach Steckdosenleist.. 40.50 € → 41.00 €`
- **Body:** Produktbild, klickbarer Produktlink, Preisdetails als Liste, Keepa-Preisgraph
- **Klick** auf die Notification öffnet direkt die Amazon-Produktseite
