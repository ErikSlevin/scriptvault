# Bitwarden Backup Skript

Dieses Bash-Skript automatisiert die Sicherung der Bitwarden-Datenbank und das Verschieben des Backups auf einen entfernten Server. Das Skript erstellt außerdem Logeinträge, um den Fortschritt und mögliche Fehler zu protokollieren.

## Anleitung

1. **Voraussetzungen:**
    - Docker muss auf dem Hostsystem installiert sein.
    - SSH-Zugriff auf den Zielserver, auf dem das Backup gespeichert werden soll.
    - Die erforderlichen Berechtigungen für das Ausführen des Skripts.

2. **Konfiguration:**
    - Stelle sicher, dass die Variablen am Anfang des Skripts entsprechend deiner Umgebung angepasst sind:
        - `backup_dir`: Pfad zum lokalen Backup-Ordner.
        - `ziel_server`: Benutzername und IP-Adresse des Ziel-Servers.
        - `ziel_backup_dir`: Zielverzeichnis auf dem entfernten Server.
        - `ziel_port`: Port für die SSH-Verbindung zum entfernten Server.
        - `ziel_identity_file`: Pfad zum Identitätsschlüssel für die SSH-Verbindung.

3. **Ausführen des Skripts:**
    - Das Skript muss mit sudo-Rechten ausgeführt werden, da es Docker-Befehle ausführt.
    - Führe das Skript aus, indem du die Befehlszeile in deinem Terminal öffnest und das Skript mit `sudo bash bw-backup-script-server-1.sh` ausführst.
    - Das Skript wird den Bitwarden-Container stoppen, ein Backup erstellen, dieses Backup auf den Zielserver verschieben und alte Backups löschen, falls mehr als 10 vorhanden sind.
    - Die Protokolle werden in der Datei `/Pfad/zum/Skript/logs/cron.log` gespeichert.

4. **Automatisierung mit Cron-Jobs:**
    - Um das Skript regelmäßig auszuführen, kannst du es in einem Cron-Job einplanen.
    - Öffne die Crontab-Konfigurationsdatei mit dem Befehl `sudo crontab -e`.
    - Füge eine Zeile hinzu, um das Skript nach deinen Anforderungen auszuführen:
        - **Alle 2 Stunden:** `0 */2 * * * sudo bash /Pfad/zum/Skript/bw-backup-script-server-1.sh`
        - **Alle 12 Stunden:** `0 */12 * * * sudo bash /Pfad/zum/Skript/bw-backup-script-server-1.sh`
        - **Alle 24 Stunden:** `0 0 * * * sudo bash /Pfad/zum/Skript/bw-backup-script-server-1.sh`
        - **Jeden Tag um 18 Uhr:** `0 18 * * * sudo bash /Pfad/zum/Skript/bw-backup-script-server-1.sh`
        - **Jeden Tag um 01:30 Uhr nachts:** `30 1 * * * sudo bash /Pfad/zum/Skript/bw-backup-script-server-1.sh`
        - **Jeden Montag:** `0 0 * * 1 sudo bash /Pfad/zum/Skript/bw-backup-script-server-1.sh`
        - **Jeden 2. des Monats:** `0 0 2 * * sudo bash /Pfad/zum/Skript/bw-backup-script-server-1.sh`
    - Ersetze `/Pfad/zum/Skript` durch den tatsächlichen Pfad zum Skript.

Für weitere Informationen und detaillierte Anpassungen siehe den Kommentar im Skript.