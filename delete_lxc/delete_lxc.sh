#!/bin/bash

# Einfaches LXC Container Lösch-Script
# Usage: delete_lxc.sh 101..120

if [ $# -eq 0 ]; then
    echo "Usage: $(basename $0) CONTAINER_IDS"
    echo "Beispiele:"
    echo "  $(basename $0) 101..120"
    echo "  $(basename $0) 101 102 103"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Fehler: Script muss als root ausgeführt werden"
    exit 1
fi

# Container-IDs sammeln
container_ids=()
for arg in "$@"; do
    if [[ "$arg" == *".."* ]]; then
        start=$(echo "$arg" | cut -d'.' -f1)
        end=$(echo "$arg" | cut -d'.' -f3)
        for ((i=start; i<=end; i++)); do
            container_ids+=("$i")
        done
    else
        container_ids+=("$arg")
    fi
done

# Existierende Container finden
existing_containers=()
for id in "${container_ids[@]}"; do
    if pct status "$id" &>/dev/null; then
        existing_containers+=("$id")
    fi
done

if [ ${#existing_containers[@]} -eq 0 ]; then
    echo "Keine existierenden Container gefunden"
    exit 1
fi

# Container anzeigen
echo "Folgende Container werden gelöscht:"
for id in "${existing_containers[@]}"; do
    status=$(pct status "$id" | awk '{print $2}')
    hostname=$(pct config "$id" | grep hostname | cut -d' ' -f2 2>/dev/null || echo "unknown")
    echo "  Container $id ($hostname) - Status: $status"
done

echo ""
read -p "Container löschen? [y/N]: " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Abgebrochen"
    exit 0
fi

# Container löschen
echo ""
for id in "${existing_containers[@]}"; do
    echo "Lösche Container $id..."
    
    # Stoppen falls läuft
    status=$(pct status "$id" | awk '{print $2}')
    if [ "$status" = "running" ]; then
        echo "  Stoppe Container $id..."
        pct stop "$id"
    fi
    
    # Löschen
    if pct destroy "$id"; then
        echo "  ✓ Container $id gelöscht"
    else
        echo "  ✗ Fehler beim Löschen von Container $id"
    fi
done

echo ""
echo "Fertig!"

# ---------------------------------------------------------------------------------
# Ausführbar machen
# sudo chmod +x /usr/local/bin/delete_lxc.sh

# Alias
# echo "alias dlxc-rm='sudo /usr/local/bin/delete_lxc.sh'" >> ~/.bashrc
# source ~/.bashrc

# Container-Bereich löschen
#dlxc-rm 101..120

# Einzelne Container
#dlxc-rm 101 102 103
