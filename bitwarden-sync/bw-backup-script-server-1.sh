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

function log_to_bitwarden() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    # Festlegen des Logformats
    local log_message="[${timestamp}][backup-script][${level}] ${message}"
    
    # Senden der Logmeldung an den Bitwarden-Container
    docker exec bitwarden sh -c "echo '${log_message}' >> /proc/1/fd/1"
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
    
    # Überprüfe, ob der Bitwarden-Container gestoppt wurde
    if docker container inspect bitwarden >/dev/null 2>&1; then
        # Starte den Bitwarden-Container erneut
        docker container start bitwarden >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            log "info" "Bitwarden Container wurde erfolgreich neu gestartet."
        else
            log "err" "Fehler: Bitwarden Container konnte nicht neu gestartet werden."
        fi
    fi
    
    # Beende das Skript mit dem angegebenen Exit-Code
    exit $exit_code
}

# Hauptskript

# Protokolliere den Start des Skripts
log "info" "Bitwarden Backup Skript Start"

# Stoppe den Bitwarden Docker-Container
docker container stop bitwarden > /dev/null 2>&1 || exit_on_error "Fehler: Dockercontainer konnte nicht gestoppt werden."
log "info" "Dockercontainer wurde gestoppt."
log_to_bitwarden "info" "Dockercontainer wurde durch das Backupscript gestoppt."

# Erstelle den Backup-Ordner, falls er nicht existiert
backup_dir="/home/erik/docker_files/vaultwarden/backup"
mkdir -p "$backup_dir" || exit_on_error "Fehler: Backup-Ordner konnte nicht erstellt werden."

# Erstelle ein Backup der Bitwarden-Daten
datum=$(date +"%y%m%d")
backup_file="$datum-pi-docker-1-bitwarden-backup.tar.gz"
tar -czf "$backup_dir/$backup_file" -C /var/lib/docker/volumes/bitwarden/_data .  || exit_on_error "Fehler: Daten konnten nicht gesichert werden."
log "info" "Daten wurden erfolgreich gesichert."

# Verschiebe das Backup auf den Zielserver
ziel_server="userk@docker-ip"
ziel_backup_dir="/home/erik/docker_files/vaultwarden/backup"
ziel_port="YOUR_PORT"
ziel_identity_file="PATH_TO_YOUR_ed25519_key"

scp -P "$ziel_port" \
    -i "$ziel_identity_file" \
    "$backup_dir/$backup_file" \
    "$ziel_server:$ziel_backup_dir/" \
    > /dev/null 2>&1 || exit_on_error "Fehler: Backup konnte nicht auf anderen Server verschoben werden."
log "info" "Backup verschoben: Datei: $backup_file"

# Lösche ältere Backups, falls mehr als 10 vorhanden sind
backup_count=$(ls -1 "$backup_dir" | grep ".*-pi-docker-1-bitwarden-backup.tar.gz" | wc -l)
if [ "$backup_count" -gt 10 ]; then
    log "info" "Es sind mehr als 10 Backups vorhanden. Lösche ältere Backups."
    ls -1t "$backup_dir" | grep ".*-pi-docker-1-bitwarden-backup.tar.gz" | tail -n +11 | xargs -I {} rm "$backup_dir/{}"
fi

# Starte den Bitwarden Docker-Container
docker container start bitwarden > /dev/null 2>&1 || exit_on_error "Fehler: Dockercontainer konnte nicht gestartet werden."
log "info" "Dockercontainer wurde erfolgreich gestartet"
log_to_bitwarden "info" "Dockercontainer wurde durch das Backupscript gestartet."

# Protokolliere das Ende des Skripts
log "info" "Bitwarden Backup Skript Ende"
