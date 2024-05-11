# Bitwarden Backup Skript

Dieses Bash-Skript automatisiert die Sicherung der Bitwarden-Datenbank und das Verschieben des Backups auf einen entfernten Server. Das Skript erstellt außerdem Logeinträge, um den Fortschritt und mögliche Fehler zu protokollieren.

## Anleitung für Server 1 (Produktiver Server)

1. **Voraussetzungen:**
    - Docker muss auf dem Produktivserver installiert sein.
    - SSH-Zugriff auf den Backup-Server, auf dem das Backup gespeichert werden soll.
    - Die erforderlichen Berechtigungen für das Ausführen des Skripts.

2. **Konfiguration:**
    - Stelle sicher, dass die Variablen am Anfang des Skripts (`bw-backup-script-server-1.sh`) entsprechend deiner Umgebung angepasst sind:
        - `backup_dir`: Pfad zum lokalen Backup-Ordner.
        - `ziel_server`: Benutzername und IP-Adresse des Backup-Servers.
        - `ziel_backup_dir`: Zielverzeichnis auf dem Backup-Server.
        - `ziel_port`: Port für die SSH-Verbindung zum Backup-Server.
        - `ziel_identity_file`: Pfad zum Identitätsschlüssel für die SSH-Verbindung.

3. **Ausführen des Skripts:**
    - Das Skript (`bw-backup-script-server-1.sh`) muss mit sudo-Rechten ausgeführt werden, da es Docker-Befehle ausführt.
    - Führe das Skript aus, indem du die Befehlszeile in deinem Terminal öffnest und das Skript mit `sudo bash bw-backup-script-server-1.sh` ausführst.
    - Das Skript wird den Bitwarden-Container stoppen, ein Backup erstellen, dieses Backup auf den Backup-Server verschieben und alte Backups löschen, falls mehr als 10 vorhanden sind.
    - Die Protokolle werden in der Datei `/Pfad/zum/Skript/logs/cron.log` gespeichert.

4. **Automatisierung mit Cron-Jobs:**
    - Um das Skript regelmäßig auszuführen, kannst du es in einem Cron-Job einplanen.
    - Öffne die Crontab-Konfigurationsdatei mit dem Befehl `sudo crontab -e`.
    - **Jeden Tag um 01:30 Uhr nachts:** `30 1 * * * sudo bash /Pfad/zum/Skript/bw-backup-script-server-1.sh`
    - Siehe unten für Beispiel-Cron-Jobs.

## Anleitung für Server 2 (Backup Server)

1. **Voraussetzungen:**
    - Docker muss auf dem Backup-Server installiert sein.

2. **Konfiguration:**
    - Stelle sicher, dass die Variablen am Anfang des Skripts (`bw-backup-script-server-2.sh`) entsprechend deiner Umgebung angepasst sind.
    - Das Skript erwartet die neueste Backup-Datei im Ordner `/home/erik/docker_files/vaultwarden/backup`.

3. **Ausführen des Skripts:**
    - Das Skript (`bw-backup-script-server-2.sh`) muss mit sudo-Rechten ausgeführt werden, da es Docker-Befehle ausführt.
    - Führe das Skript aus, indem du die Befehlszeile in deinem Terminal öffnest und das Skript mit `sudo bash bw-backup-script-server-2.sh` ausführst.
    - Das Skript wird den Bitwarden-Container stoppen, alle Daten im Bitwarden-Datenverzeichnis löschen, das neueste Backup entpacken, den Bitwarden-Container starten und alte Backups löschen, falls mehr als 10 vorhanden sind.
    - Die Protokolle werden in der Datei `/Pfad/zum/Skript/logs/cron.log` gespeichert.

4. **Automatisierung mit Cron-Jobs:**
    - Um das Skript regelmäßig auszuführen, kannst du es in einem Cron-Job einplanen.
    - Öffne die Crontab-Konfigurationsdatei mit dem Befehl `sudo crontab -e`.
    - **Jeden Tag um 01:35 Uhr nachts:** `35 1 * * * sudo bash /Pfad/zum/Skript/bw-backup-script-server-2.sh`
    - Siehe unten für Beispiel-Cron-Jobs.


## Logger

- Logger anpassen: ```/etc/systemd/journald.conf```
```yaml
[Journal]
SplitMode=syslog
SyslogIdentifier=bitwarden_backup
SystemMaxUse=50M
SystemKeepFree=100M
RuntimeMaxUse=50M
RuntimeKeepFree=100M
Storage=persistent
```
- journald neustarten: ```sudo systemctl restart systemd-journald```
- journald auslesen: ```journalctl -t bitwarden_backup```

Beispielausgabe:
```
Mai 11 23:57:14 pi-docker-1 bitwarden_backup[690373]: info: Bitwarden Backup Skript Start
Mai 11 23:57:14 pi-docker-1 bitwarden_backup[690385]: info: Dockercontainer wurde erfolgreich gestoppt.
Mai 11 23:57:14 pi-docker-1 bitwarden_backup[690399]: info: Daten wurden erfolgreich gesichert.
Mai 11 23:57:14 pi-docker-1 bitwarden_backup[690407]: info: Backup verschoben: Datei: 240511-pi-docker-1-bitwarden-backup.tar.gz
Mai 11 23:57:15 pi-docker-1 bitwarden_backup[690447]: info: Bitwarden Container auf Remote-Server wurde erfolgreich gestoppt.
Mai 11 23:57:15 pi-docker-1 bitwarden_backup[690453]: info: Bitwarden Backup Skript Ende
Mai 12 00:01:15 pi-docker-1 bitwarden_backup[693155]: info: Bitwarden Backup Skript Start
Mai 12 00:01:15 pi-docker-1 bitwarden_backup[693168]: info: Dockercontainer wurde erfolgreich gestoppt.
Mai 12 00:01:15 pi-docker-1 bitwarden_backup[693179]: info: Daten wurden erfolgreich gesichert.
Mai 12 00:01:16 pi-docker-1 bitwarden_backup[693187]: info: Backup verschoben: Datei: 240512-pi-docker-1-bitwarden-backup.tar.gz
Mai 12 00:01:16 pi-docker-1 bitwarden_backup[693193]: info: Bitwarden Backup Skript Ende
```