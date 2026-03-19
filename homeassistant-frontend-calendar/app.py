from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import paramiko
import json
import uuid
from datetime import datetime, date
from icalendar import Calendar, Event, vText
import io
import logging
import requests
from zoneinfo import ZoneInfo

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

LOCAL_TZ = ZoneInfo("Europe/Berlin")

app = FastAPI(title="Kalender API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

with open("config.json") as f:
    CONFIG = json.load(f)


def ha_reload_calendar():
    """Kalender-Integration in HA neu laden."""
    try:
        ha_url = CONFIG.get("ha_url", "").rstrip("/")
        ha_token = CONFIG.get("ha_token", "")
        if not ha_url or not ha_token:
            logger.warning("ha_url oder ha_token fehlt in config.json — HA-Reload übersprungen")
            return
        headers = {"Authorization": f"Bearer {ha_token}", "Content-Type": "application/json"}
        # Config-Entries laden und local_calendar finden
        r = requests.get(f"{ha_url}/api/config/config_entries/entry", headers=headers, timeout=5)
        entries = r.json()
        entry_id = None
        for e in entries:
            if e.get("domain") == "local_calendar":
                entry_id = e.get("entry_id")
                break
        if not entry_id:
            logger.warning("local_calendar Config-Entry nicht gefunden")
            return
        requests.post(f"{ha_url}/api/config/config_entries/entry/{entry_id}/reload", headers=headers, timeout=5)
        logger.info("HA Calendar neu geladen ✓")
    except Exception as ex:
        logger.warning(f"HA-Reload fehlgeschlagen (nicht kritisch): {ex}")


def get_ssh_client():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    connect_kwargs = {
        "hostname": CONFIG["ha_host"],
        "port": CONFIG.get("ha_ssh_port", 22222),
        "username": CONFIG.get("ha_ssh_user", "root"),
    }
    if CONFIG.get("ha_ssh_key"):
        connect_kwargs["key_filename"] = CONFIG["ha_ssh_key"]
    else:
        connect_kwargs["password"] = CONFIG.get("ha_ssh_password")
    client.connect(**connect_kwargs)
    return client


def ssh_read_ics() -> bytes:
    client = get_ssh_client()
    try:
        sftp = client.open_sftp()
        with sftp.open(CONFIG["ics_path"], "rb") as f:
            return f.read()
    finally:
        client.close()


def ssh_write_ics(content: bytes):
    client = get_ssh_client()
    try:
        sftp = client.open_sftp()
        # Backup anlegen
        try:
            sftp.rename(CONFIG["ics_path"], CONFIG["ics_path"] + ".bak")
        except Exception:
            pass
        with sftp.open(CONFIG["ics_path"], "wb") as f:
            f.write(content)
    finally:
        client.close()


def ics_to_events(content: bytes) -> list:
    cal = Calendar.from_ical(content)
    events = []
    for component in cal.walk():
        if component.name != "VEVENT":
            continue
        try:
            dtstart = component.get("DTSTART").dt
            dtend = component.get("DTEND").dt
            all_day = isinstance(dtstart, date) and not isinstance(dtstart, datetime)
            # Timed events: in lokale Zeit konvertieren damit das Datum stimmt
            if not all_day:
                if hasattr(dtstart, 'tzinfo') and dtstart.tzinfo is not None:
                    dtstart = dtstart.astimezone(LOCAL_TZ)
                if hasattr(dtend, 'tzinfo') and dtend.tzinfo is not None:
                    dtend = dtend.astimezone(LOCAL_TZ)
            events.append({
                "uid": str(component.get("UID", "")),
                "summary": str(component.get("SUMMARY", "")),
                "description": str(component.get("DESCRIPTION", "")),
                "start": dtstart.isoformat(),
                "end": dtend.isoformat(),
                "all_day": all_day,
            })
        except Exception as e:
            logger.warning(f"Event übersprungen: {e}")
    return events


class EventIn(BaseModel):
    summary: str
    description: Optional[str] = ""
    start_date: str   # YYYY-MM-DD
    end_date: str     # YYYY-MM-DD
    all_day: bool = True
    start_time: Optional[str] = "00:00"
    end_time: Optional[str] = "01:00"


@app.get("/", response_class=HTMLResponse)
def index():
    with open("templates/index.html", encoding="utf-8") as f:
        return f.read()


@app.get("/api/events")
def get_events(year: int, month: int, wide: int = 0):
    try:
        content = ssh_read_ics()
        all_events = ics_to_events(content)
        result = []
        # Monatsbereich berechnen
        month_start = date(year, month, 1)
        if month == 12:
            month_end = date(year + 1, 1, 1)
        else:
            month_end = date(year, month + 1, 1)

        for e in all_events:
            try:
                ev_start = date.fromisoformat(e["start"][:10])
                ev_end = date.fromisoformat(e["end"][:10])
                # Event überschneidet sich mit dem Monat?
                if ev_start < month_end and ev_end >= month_start:
                    result.append(e)
            except Exception:
                pass
        return result
    except Exception as ex:
        logger.error(f"Fehler beim Lesen: {ex}")
        raise HTTPException(status_code=500, detail=str(ex))


@app.post("/api/events")
def create_event(ev: EventIn):
    try:
        content = ssh_read_ics()
        cal = Calendar.from_ical(content)

        new_ev = Event()
        new_ev.add("SUMMARY", ev.summary)
        new_ev.add("DESCRIPTION", ev.description or "")
        new_ev.add("UID", str(uuid.uuid4()))
        new_ev.add("DTSTAMP", datetime.utcnow())
        new_ev.add("CREATED", datetime.utcnow())
        new_ev.add("SEQUENCE", 0)

        if ev.all_day:
            new_ev.add("DTSTART", date.fromisoformat(ev.start_date))
            new_ev.add("DTEND", date.fromisoformat(ev.end_date))
        else:
            new_ev.add("DTSTART", datetime.fromisoformat(f"{ev.start_date}T{ev.start_time}:00"))
            new_ev.add("DTEND", datetime.fromisoformat(f"{ev.end_date}T{ev.end_time}:00"))

        cal.add_component(new_ev)
        ssh_write_ics(cal.to_ical())
        ha_reload_calendar()
        return {"status": "ok"}
    except Exception as ex:
        logger.error(f"Fehler beim Erstellen: {ex}")
        raise HTTPException(status_code=500, detail=str(ex))


@app.put("/api/events/{uid}")
def update_event(uid: str, ev: EventIn):
    try:
        content = ssh_read_ics()
        cal = Calendar.from_ical(content)

        new_cal = Calendar()
        for attr in ["VERSION", "PRODID", "CALSCALE", "METHOD"]:
            if cal.get(attr):
                new_cal.add(attr, cal[attr])

        found = False
        for component in cal.walk():
            if component.name == "VEVENT":
                if str(component.get("UID")) == uid:
                    found = True
                    component["SUMMARY"] = vText(ev.summary)
                    component["DESCRIPTION"] = vText(ev.description or "")
                    for key in ["DTSTART", "DTEND"]:
                        if key in component:
                            del component[key]
                    if ev.all_day:
                        component.add("DTSTART", date.fromisoformat(ev.start_date))
                        component.add("DTEND", date.fromisoformat(ev.end_date))
                    else:
                        component.add("DTSTART", datetime.fromisoformat(f"{ev.start_date}T{ev.start_time}:00"))
                        component.add("DTEND", datetime.fromisoformat(f"{ev.end_date}T{ev.end_time}:00"))
                new_cal.add_component(component)
            elif component.name != "VCALENDAR":
                new_cal.add_component(component)

        if not found:
            raise HTTPException(status_code=404, detail="Ereignis nicht gefunden")

        ssh_write_ics(new_cal.to_ical())
        ha_reload_calendar()
        return {"status": "ok"}
    except HTTPException:
        raise
    except Exception as ex:
        logger.error(f"Fehler beim Bearbeiten: {ex}")
        raise HTTPException(status_code=500, detail=str(ex))


@app.delete("/api/events/{uid}")
def delete_event(uid: str):
    try:
        content = ssh_read_ics()
        cal = Calendar.from_ical(content)

        new_cal = Calendar()
        for attr in ["VERSION", "PRODID", "CALSCALE", "METHOD"]:
            if cal.get(attr):
                new_cal.add(attr, cal[attr])

        deleted = False
        for component in cal.walk():
            if component.name == "VEVENT":
                if str(component.get("UID")) == uid:
                    deleted = True
                    continue
                new_cal.add_component(component)
            elif component.name != "VCALENDAR":
                new_cal.add_component(component)

        if not deleted:
            raise HTTPException(status_code=404, detail="Ereignis nicht gefunden")

        ssh_write_ics(new_cal.to_ical())
        ha_reload_calendar()
        return {"status": "ok"}
    except HTTPException:
        raise
    except Exception as ex:
        logger.error(f"Fehler beim Löschen: {ex}")
        raise HTTPException(status_code=500, detail=str(ex))
