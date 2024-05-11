#!/bin/bash

# Funktion für Logeinträge mit Level, Nachricht und Datum/Zeit
# Argumente:
#   $1: Das Log-Level (z.B. "info", "err")
#   $2: Die Nachricht, die protokolliert werden soll
function log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local log_file="/home/erik/docker_files/vaultwarden/logs/cron.log"

    # Protokolliere die Nachricht in die Log-Datei
    echo -e "$timestamp $message" >> "$log_file"
    # Leite die Nachricht an den System-Logger weiter
    echo -e "$level: $message" | logger -t bitwarden_backup -p user.$(echo $level | tr '[:lower:]' '[:upper:]')
}

# Funktion zum Beenden des Skripts bei einem Fehler
# Argumente:
#   $1: Die Fehlermeldung
#   $2: Der Exit-Code (optional, Standardwert: 1)
function exit_on_error() {
    local message=$1
    local exit_code=${2:-1}  # Standard-Exit-Code ist 1, wenn nicht anders angegeben

    # Protokolliere den Fehler
    log "err" "$message"
    
    # Beende das Skript mit dem angegebenen Exit-Code
    exit $exit_code
}

# Hauptskript

# Protokolliere den Start des Skripts
log "info" "Bitwarden Restore Skript Start"

# Stoppe den Bitwarden Docker-Container
docker container stop bitwarden > /dev/null 2>&1 || exit_on_error "Fehler: Dockercontainer konnte nicht gestoppt werden."
log "info" "Dockercontainer wurde erfolgreich gestoppt."

# Lösche alle Daten im Bitwarden-Datenverzeichnis
rm -rf /var/lib/docker/volumes/bitwarden/_data/* || exit_on_error "Fehler: Daten im Bitwarden-Datenverzeichnis konnten nicht gelöscht werden."
log "info" "Alle Daten im Bitwarden-Datenverzeichnis wurden erfolgreich gelöscht."

# Entpacke das neueste Backup in das Bitwarden-Datenverzeichnis
backup_dir="/home/erik/docker_files/vaultwarden/backup"
latest_backup=$(ls -t "$backup_dir" | head -1)
tar -xzf "$backup_dir/$latest_backup" -C /var/lib/docker/volumes/bitwarden/_data/ || exit_on_error "Fehler: Neuestes Backup konnte nicht in das Bitwarden-Datenverzeichnis entpackt werden."
log "info" "Neuestes Backup wurde erfolgreich in das Bitwarden-Datenverzeichnis entpackt: $latest_backup"

# Starte den Bitwarden Docker-Container
docker container start bitwarden > /dev/null 2>&1 || exit_on_error "Fehler: Dockercontainer konnte nicht gestartet werden."
log "info" "Dockercontainer wurde erfolgreich gestartet."

# Lösche ältere Backups, falls mehr als 10 vorhanden sind
backup_count=$(ls -1 "$backup_dir" | wc -l)
if [ "$backup_count" -gt 10 ]; then
    log "info" "Es sind mehr als 30 Backups vorhanden. Lösche ältere Backups."
    ls -1t "$backup_dir" | tail -n +31 | xargs -I {} rm "$backup_dir/{}"
fi

# Protokolliere das Ende des Skripts
log "info" "Bitwarden Restore Skript Ende"

