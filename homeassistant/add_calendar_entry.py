#!/usr/bin/env python3
"""
Schichtplan-Import für Home Assistant
Optimierte Version: Nutzt Sessions, automatische Datumsberechnung und Environment-Vars.
"""

import os
import sys
import requests
from datetime import datetime, timedelta
from typing import List, Tuple, Optional, Dict

# === KONFIGURATION ===
# Lese Token aus Umgebungsvariable (Sicherer!) oder nutze Fallback (weniger sicher)
# Setze die Variable im Terminal via: export HA_TOKEN="dein_neuer_langer_token"
HA_TOKEN = os.getenv("HA_TOKEN", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJkNmNmMTQ2NzA5ZXXXXXXXXXXXXXXXXXX")
HA_URL = "http://homeassistant.home.intern:8123"
CALENDAR_ID = "calendar.anne_arbeit"

# Zeitformat für interne Berechnungen
FMT_TIME = "%H:%M"
FMT_DATE = "%Y-%m-%d"

# Definition der Schichten
# Name: (Startzeit, Endzeit). None für Ganztagesevents (Frei)
SCHICHT_DEFS: Dict[str, Optional[Tuple[str, str]]] = {
    "Früh":  ("06:30", "14:45"),
    "Spät":  ("14:15", "22:30"),
    "Nacht": ("22:00", "07:00"),
    "Frei":  None,
}

# === SCHICHTPLAN DATEN ===
SCHICHTPLAN: List[Tuple[str, str]] = [
    ("2026-02-01", "Frei"),
    ("2026-02-02", "Nacht"),
    ("2026-02-03", "Nacht"),
    ("2026-02-04", "Nacht"),
    ("2026-02-05", "Frei"),
    ("2026-02-06", "Frei"),
    ("2026-02-07", "Spät"),
    ("2026-02-08", "Spät"),
    ("2026-02-09", "Frei"),
    ("2026-02-10", "Früh"),
    ("2026-02-11", "Früh"),
    ("2026-02-12", "Früh"),
    ("2026-02-13", "Spät"),
    ("2026-02-14", "Frei"),
    ("2026-02-15", "Frei"),
    ("2026-02-16", "Früh"),
    ("2026-02-17", "Früh"),
    ("2026-02-18", "Spät"),
    ("2026-02-19", "Spät"),
    ("2026-02-20", "Frei"),
    ("2026-02-21", "Früh"),
    ("2026-02-22", "Früh"),
    ("2026-02-23", "Nacht"),
    ("2026-02-24", "Nacht"),
    ("2026-02-25", "Nacht"),
    ("2026-02-26", "Frei"),
    ("2026-02-27", "Frei"),
    ("2026-02-28", "Früh"),
]

def create_payload(datum_str: str, schicht_name: str) -> Optional[dict]:
    """Erstellt das JSON Payload für die Home Assistant API."""
    if schicht_name not in SCHICHT_DEFS:
        print(f"  ? Warnung: Unbekannte Schicht '{schicht_name}' am {datum_str}")
        return None

    zeiten = SCHICHT_DEFS[schicht_name]
    
    # Basis-Payload
    payload = {
        "entity_id": CALENDAR_ID,
        "summary": schicht_name,
    }

    # Fall 1: Ganztages-Event (Frei)
    if zeiten is None:
        start_date = datetime.strptime(datum_str, FMT_DATE)
        end_date = start_date + timedelta(days=1)
        payload.update({
            "start_date": start_date.strftime(FMT_DATE),
            "end_date": end_date.strftime(FMT_DATE) # Exklusiv, daher nächster Tag
        })
        return payload

    # Fall 2: Zeit-basiertes Event (Schichten)
    start_time_str, end_time_str = zeiten
    
    # Erstelle volle DateTime Objekte
    dt_start = datetime.strptime(f"{datum_str} {start_time_str}", f"{FMT_DATE} {FMT_TIME}")
    dt_end = datetime.strptime(f"{datum_str} {end_time_str}", f"{FMT_DATE} {FMT_TIME}")

    # Automatische Erkennung von Nachtschichten:
    # Wenn Ende VOR Start liegt, muss das Ende am nächsten Tag sein.
    if dt_end < dt_start:
        dt_end += timedelta(days=1)

    payload.update({
        "start_date_time": dt_start.isoformat(),
        "end_date_time": dt_end.isoformat(),
    })
    
    return payload

def main():
    if "HIER_NEUEN_TOKEN" in HA_TOKEN:
        print("ACHTUNG: Bitte Token konfigurieren!")
        sys.exit(1)

    url = f"{HA_URL}/api/services/calendar/create_event"
    headers = {
        "Authorization": f"Bearer {HA_TOKEN}",
        "Content-Type": "application/json",
    }

    stats = {"ok": 0, "fail": 0, "skip": 0}

    print(f"Starte Import für {CALENDAR_ID}...")
    
    # Session für Performance (Keep-Alive)
    with requests.Session() as session:
        session.headers.update(headers)

        for datum, schicht in SCHICHTPLAN:
            payload = create_payload(datum, schicht)
            
            if not payload:
                stats["skip"] += 1
                continue

            try:
                response = session.post(url, json=payload, timeout=5)
                response.raise_for_status() # Wirft Fehler bei HTTP 4xx/5xx
                
                print(f"  ✓ {datum}: {schicht}")
                stats["ok"] += 1

            except requests.exceptions.RequestException as e:
                msg = str(e)
                if hasattr(e, 'response') and e.response is not None:
                    msg = f"HTTP {e.response.status_code}: {e.response.text}"
                print(f"  ✗ {datum}: {schicht} — Fehler: {msg}")
                stats["fail"] += 1

    print(f"\n--- Fertig ---")
    print(f"Erfolgreich: {stats['ok']}")
    print(f"Fehler:      {stats['fail']}")
    print(f"Übersprungen:{stats['skip']}")

if __name__ == "__main__":
    main()
