# Annes Kalender

Web-Oberfläche für den Home Assistant Local Calendar (`calendar.anne_arbeit`).  
Liest und schreibt direkt die ICS-Datei per SSH auf dem HA-Host.

## Features

- Monatsansicht (Mobile & Desktop)
- Schicht-Schnellauswahl: Früh / Spät / Nacht (22–07 Uhr) / Frei
- Ereignisse erstellen, bearbeiten, löschen
- Massenimport via Python-Tupel-Format
- Dark / Light Mode
- HA Calendar wird nach jeder Änderung automatisch neu geladen

---

## Voraussetzungen

- Proxmox LXC (Ubuntu 22.04+, 512 MB RAM)
- Home Assistant OS mit aktiviertem SSH (Port prüfen: `netstat -tulpn | grep ssh`)
- HA Long-Lived Access Token

---

## Installation

### 1. LXC anlegen (Proxmox)

Ubuntu 22.04, 512 MB RAM, 4 GB Disk, Netzwerk per DHCP.

### 2. Dateien auf den LXC kopieren

```bash
scp -r kalender/ root@LXC-IP:/root/kalender
ssh root@LXC-IP
cd /root/kalender
```

### 3. Installieren

```bash
chmod +x install.sh && ./install.sh
```

Das Skript:
- Installiert Python-Abhängigkeiten im venv
- Generiert einen SSH-Key unter `/opt/kalender/ha_key`
- Richtet einen systemd-Service ein

### 4. SSH-Key in HA eintragen

Den angezeigten Public Key in Home Assistant eintragen:

```bash
# Auf dem HA-Host:
echo "HIER_PUBLIC_KEY" >> /root/.ssh/authorized_keys
```

### 5. config.json anpassen

```bash
nano /opt/kalender/config.json
```

| Parameter | Beschreibung |
|---|---|
| `ha_host` | Hostname/IP des HA-Hosts |
| `ha_ssh_port` | SSH-Port (Standard HA OS: 22222, prüfen mit `netstat -tulpn`) |
| `ha_ssh_user` | SSH-Benutzer (meist `root`) |
| `ha_ssh_key` | Pfad zum privaten SSH-Key |
| `ics_path` | Pfad zur ICS-Datei auf dem HA-Host |
| `ha_url` | HA-URL inkl. Port |
| `ha_token` | Long-Lived Access Token (HA → Profil → Sicherheit → Token) |

### 6. Service neu starten

```bash
systemctl restart kalender
systemctl status kalender
```

Die App ist erreichbar unter: `http://LXC-IP:8000`

---

## Update (neue Version einspielen)

```bash
scp app.py root@LXC-IP:/opt/kalender/app.py
scp templates/index.html root@LXC-IP:/opt/kalender/templates/index.html
ssh root@LXC-IP systemctl restart kalender
```

---

## DNS (empfohlen)

In Technitium DNS einen A-Record anlegen:  
`kalender.home.intern → LXC-IP`

Dann in NPM als Reverse Proxy eintragen falls gewünscht.

---

## Massenimport Format

```python
("2026-05-01", "Früh"),
("2026-05-02", "Spät"),
("2026-05-03", "Nacht"),
("2026-05-04", "Frei"),
```

Gültige Schichtnamen: `Früh`, `Spät`, `Nacht`, `Frei`  
Nachtschicht wird automatisch als 22:00–07:00 (Folgetag) gespeichert.
