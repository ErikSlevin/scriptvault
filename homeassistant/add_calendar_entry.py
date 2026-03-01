#!/usr/bin/env python3
"""
Schichtplan-Import für Home Assistant Kalender (calendar.anne_arbeit)

Dieses Skript liest einen statisch definierten Schichtplan und importiert
alle Einträge über die Home Assistant REST API als Kalenderevents.

Unterstützte Schichttypen:
  - Zeitbasierte Schichten (Früh, Spät, Nacht) → werden als DateTime-Events angelegt
  - Ganztags-Einträge (Frei, Urlaub)           → werden als ganztägige Events angelegt
  - Nachtschichten werden automatisch erkannt, wenn das Ende vor dem Start liegt

Nutzung:
  export HA_TOKEN="dein_token"
  python3 schichtplan_import.py
"""

import os
import sys
import requests
from datetime import datetime, timedelta
from typing import List, Tuple, Optional, Dict

# =============================================================================
# KONFIGURATION
# =============================================================================

# Long-lived Access Token aus Home Assistant (Profil → Sicherheit → Token erstellen).
# Sicherer: Token als Umgebungsvariable übergeben, statt ihn direkt im Code zu haben.
#   → Terminal: export HA_TOKEN="eyJ..."
# Fallback ist der hartcodierte Token (nicht empfohlen für geteilte Repos / Versionierung).
HA_TOKEN = os.getenv("HA_TOKEN", "check Bitwarden")

# Basis-URL der Home Assistant Instanz (intern erreichbar über DNS)
HA_URL = "http://homeassistant.home.intern:8123"

# Entity-ID des Ziel-Kalenders in Home Assistant
CALENDAR_ID = "calendar.anne_arbeit"

# Datumsformat für datetime.strptime() / strftime()
FMT_TIME = "%H:%M"       # z. B. "06:30"
FMT_DATE = "%Y-%m-%d"    # z. B. "2026-05-14"

# =============================================================================
# SCHICHTDEFINITIONEN
# =============================================================================

# Jede Schicht ist entweder:
#   - Ein Tupel (Startzeit, Endzeit) als String → zeitbasiertes Event
#   - None                                      → ganztägiges Event
#
# Zeiten immer im 24h-Format. Nachtschichten, bei denen das Ende am Folgetag
# liegt (z. B. 22:00–07:00), werden in create_payload() automatisch korrigiert.
SCHICHT_DEFS: Dict[str, Optional[Tuple[str, str]]] = {
    "Früh":   ("06:30", "14:45"),   # Frühschicht
    "Spät":   ("14:15", "22:30"),   # Spätschicht
    "Nacht":  ("22:00", "07:00"),   # Nachtschicht (endet am Folgetag → auto-korrigiert)
    "Frei":   None,                 # freier Tag → ganztägiges Event
    "Urlaub": None,                 # Urlaub     → ganztägiges Event (wird gesondert befüllt)
}

# =============================================================================
# SCHICHTPLAN DATEN
# =============================================================================

# Urlaubsblöcke als Liste von (Startdatum, Enddatum_inklusive, Titel).
# Das Enddatum ist INKLUSIVE – die API erwartet exklusiv, daher +1 Tag in create_urlaub_payload().
URLAUB: List[Tuple[str, str, str]] = [
    ("2026-05-01", "2026-05-13", "Urlaub"),
]

# Einzelne Schichttage als Liste von (Datum, Schichtname).
# Schichtname muss exakt einem Schlüssel in SCHICHT_DEFS entsprechen.
SCHICHTPLAN: List[Tuple[str, str]] = [
    ("2026-05-14", "Früh"),
    ("2026-05-15", "Frei"),
    ("2026-05-16", "Nacht"),
    ("2026-05-17", "Frei"),
    ("2026-05-18", "Früh"),
    ("2026-05-19", "Früh"),
    ("2026-05-20", "Früh"),
    ("2026-05-21", "Früh"),
    ("2026-05-22", "Nacht"),
    ("2026-05-23", "Frei"),
    ("2026-05-24", "Spät"),
    ("2026-05-25", "Spät"),
    ("2026-05-26", "Spät"),
    ("2026-05-27", "Spät"),
    ("2026-05-28", "Frei"),
    ("2026-05-29", "Nacht"),
    ("2026-05-30", "Frei"),
]

# =============================================================================
# HILFSFUNKTIONEN
# =============================================================================

def create_payload(datum_str: str, schicht_name: str) -> Optional[dict]:
    """
    Erstellt das JSON-Payload für die HA-API anhand von Datum und Schichtname.

    Unterscheidet zwei Fälle:
      1. Ganztages-Event (SCHICHT_DEFS-Wert ist None):
           start_date / end_date werden als ISO-Datumstrings übergeben.
           end_date ist exklusiv → immer Folgetag.
      2. Zeitbasiertes Event (SCHICHT_DEFS-Wert ist ein Zeitpaar):
           start_date_time / end_date_time werden als ISO-8601-Datetime übergeben.
           Liegt end_time < start_time (Nachtschicht), wird end +1 Tag verschoben.

    Args:
        datum_str:    Datum im Format YYYY-MM-DD (z. B. "2026-05-16")
        schicht_name: Name der Schicht, muss in SCHICHT_DEFS vorhanden sein

    Returns:
        dict mit dem fertigen API-Payload oder None bei Fehler
    """
    if schicht_name not in SCHICHT_DEFS:
        print(f"  ? Warnung: Unbekannte Schicht '{schicht_name}' am {datum_str}")
        return None

    zeiten = SCHICHT_DEFS[schicht_name]

    # Basis-Payload – gilt für alle Event-Typen
    payload = {
        "entity_id": CALENDAR_ID,
        "summary":   schicht_name,
    }

    if zeiten is None:
        # --- Ganztages-Event (Frei / Urlaub-Einzeltag) ---
        start_date = datetime.strptime(datum_str, FMT_DATE)
        end_date   = start_date + timedelta(days=1)  # HA erwartet exklusives Enddatum

        payload.update({
            "start_date": start_date.strftime(FMT_DATE),
            "end_date":   end_date.strftime(FMT_DATE),
        })
        return payload

    # --- Zeitbasiertes Event (Schicht mit konkreten Uhrzeiten) ---
    start_time_str, end_time_str = zeiten

    # Kombiniere Datum + Uhrzeit zu vollständigen datetime-Objekten
    dt_start = datetime.strptime(f"{datum_str} {start_time_str}", f"{FMT_DATE} {FMT_TIME}")
    dt_end   = datetime.strptime(f"{datum_str} {end_time_str}",   f"{FMT_DATE} {FMT_TIME}")

    # Nachtschicht-Erkennung: Wenn Endzeit < Startzeit, endet die Schicht am Folgetag
    # Beispiel: 22:00 → 07:00  wird zu  22:00 (Tag X) → 07:00 (Tag X+1)
    if dt_end < dt_start:
        dt_end += timedelta(days=1)

    payload.update({
        "start_date_time": dt_start.isoformat(),
        "end_date_time":   dt_end.isoformat(),
    })

    return payload


def create_urlaub_payload(start_str: str, end_inklusiv_str: str, titel: str) -> Optional[dict]:
    """
    Erstellt das JSON-Payload für einen mehrtägigen Urlaubsblock.

    Das übergebene Enddatum ist INKLUSIVE (menschenlesbar).
    Die HA-API erwartet das Enddatum EXKLUSIV → es wird automatisch um +1 Tag verschoben.

    Beispiel: ("2026-05-01", "2026-05-13", "Urlaub")
      → API erhält start_date=2026-05-01, end_date=2026-05-14

    Args:
        start_str:       Startdatum inklusive (YYYY-MM-DD)
        end_inklusiv_str: Enddatum inklusive  (YYYY-MM-DD)
        titel:           Bezeichnung des Events (z. B. "Urlaub")

    Returns:
        dict mit dem fertigen API-Payload oder None bei Fehler
    """
    try:
        dt_start = datetime.strptime(start_str,        FMT_DATE)
        dt_end   = datetime.strptime(end_inklusiv_str, FMT_DATE) + timedelta(days=1)
    except ValueError as e:
        print(f"  ? Warnung: Ungültiges Datum bei '{titel}': {e}")
        return None

    # Plausibilitätsprüfung: Enddatum muss nach Startdatum liegen
    if dt_end <= dt_start:
        print(f"  ? Warnung: Enddatum vor Startdatum bei '{titel}'")
        return None

    return {
        "entity_id":  CALENDAR_ID,
        "summary":    titel,
        "start_date": dt_start.strftime(FMT_DATE),
        "end_date":   dt_end.strftime(FMT_DATE),
    }


# =============================================================================
# HAUPTPROGRAMM
# =============================================================================

def main():
    # Sicherheitscheck: Verhindert Ausführung mit nicht ersetztem Platzhalter-Token
    if "HIER_NEUEN_TOKEN" in HA_TOKEN:
        print("ACHTUNG: Bitte Token konfigurieren!")
        sys.exit(1)

    # API-Endpunkt für das Erstellen von Kalenderevents
    url = f"{HA_URL}/api/services/calendar/create_event"

    # HTTP-Header: Bearer-Auth + JSON Content-Type
    headers = {
        "Authorization": f"Bearer {HA_TOKEN}",
        "Content-Type":  "application/json",
    }

    # Zähler für die abschließende Zusammenfassung
    stats = {"ok": 0, "fail": 0, "skip": 0}

    print(f"Starte Import für {CALENDAR_ID}...")

    # requests.Session() ermöglicht HTTP Keep-Alive → weniger Verbindungsaufbau-Overhead
    # bei vielen aufeinanderfolgenden Requests an denselben Host
    with requests.Session() as session:
        session.headers.update(headers)

        # --- Schichtplan-Einträge ---
        for datum, schicht in SCHICHTPLAN:
            payload = create_payload(datum, schicht)

            if not payload:
                # Payload-Erstellung hat fehlgeschlagen (z. B. unbekannte Schicht)
                stats["skip"] += 1
                continue

            try:
                response = session.post(url, json=payload, timeout=5)
                response.raise_for_status()  # Löst Exception bei HTTP 4xx / 5xx aus

                print(f"  ✓ {datum}: {schicht}")
                stats["ok"] += 1

            except requests.exceptions.RequestException as e:
                # Detaillierten Fehlertext aus der HTTP-Antwort extrahieren (falls vorhanden)
                msg = str(e)
                if hasattr(e, "response") and e.response is not None:
                    msg = f"HTTP {e.response.status_code}: {e.response.text}"
                print(f"  ✗ {datum}: {schicht} — Fehler: {msg}")
                stats["fail"] += 1

        # --- Urlaubsblöcke ---
        print("\n[Urlaub]")
        for start, ende, titel in URLAUB:
            payload = create_urlaub_payload(start, ende, titel)

            if not payload:
                stats["skip"] += 1
                continue

            try:
                response = session.post(url, json=payload, timeout=5)
                response.raise_for_status()

                print(f"  ✓ {start} – {ende}: {titel}")
                stats["ok"] += 1

            except requests.exceptions.RequestException as e:
                msg = str(e)
                if hasattr(e, "response") and e.response is not None:
                    msg = f"HTTP {e.response.status_code}: {e.response.text}"
                print(f"  ✗ {start} – {ende}: {titel} — Fehler: {msg}")
                stats["fail"] += 1

    # Abschlusszusammenfassung
    print(f"\n--- Fertig ---")
    print(f"Erfolgreich:  {stats['ok']}")
    print(f"Fehler:       {stats['fail']}")
    print(f"Übersprungen: {stats['skip']}")


if __name__ == "__main__":
    main()
