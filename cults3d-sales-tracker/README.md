# cults3d-monitor

Trackt die Performance deiner [Cults3D](https://cults3d.com)-Designs (Views, Likes, Downloads, Umsatz, Verkaeufe) per GraphQL API und speichert die Metriken in InfluxDB 1.x. Inkl. fertigem Grafana Dashboard.

![Dashboard](screenshots/dashboard-overview.png)
![Details](screenshots/dashboard-details.png)

## Voraussetzungen

- Linux mit `curl` und `jq`
- InfluxDB 1.x
- Grafana 10+
- [Cults3D API-Key](https://cults3d.com/en/api/keys)

## Installation

```bash
nano cults3d-monitor.conf   # Zugangsdaten eintragen
sudo bash setup.sh
```
> **Hinweis:** Der Username ist dein Cults-Profilname (Nickname), nicht die E-Mail-Adresse.

## Verwendung

```bash
# Manueller Testlauf
/opt/cults3d-monitor/cults3d-monitor.sh

# Timer-Status
systemctl status cults3d-monitor.timer

# Logs
journalctl -u cults3d-monitor.service -n 30
```

## Grafana Dashboard

1. InfluxDB Datasource anlegen (Datenbank: `cults3d`)
2. Dashboards → Import → `grafana/cults3d-dashboard.json` hochladen
3. Datasource zuweisen → Import

## Timer anpassen

```bash
sudo nano /etc/systemd/system/cults3d-monitor.timer
```

```ini
# Stuendlich (Standard)
OnCalendar=*-*-* *:00:00

# Taeglich um 06:00
OnCalendar=*-*-* 06:00:00
```

```bash
sudo systemctl daemon-reload && sudo systemctl restart cults3d-monitor.timer
```

## API-Verbrauch

2 Aufrufe pro Lauf. Rate-Limit: ~500/Tag. Stuendlich = 48/Tag.
