#!/bin/bash
###############################################################################
# unifi-technitium-sync.sh
#
# Gleicht UniFi-Clients (MongoDB) mit Technitium DHCP-Leases ab.
#
# Änderungen:
#   - Here-Docs entfernt (behebt Syntax-Fehler bei Einrückung)
#   - MongoDB-Befehle werden als sichere Strings übertragen
#   - Nutzt effizientes BulkWrite für die Datenbank
###############################################################################
set -euo pipefail

# ========================== KONFIGURATION ==========================
TECHNITIUM_URL="http://dns.home.intern:5380"
TECHNITIUM_TOKEN="dab4f2dec5933a5766fc8b72baae588bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
UNIFI_SSH_HOST="unifi"
UNIFI_MONGO_PORT="27117"
UNIFI_MONGO_DB="ace"
DOMAIN_SUFFIX=".home.intern"
RESTART_UNIFI=true

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Flags
DRY_RUN=true
SHOW_ALL=false
USE_FQDN=false

for arg in "$@"; do
    case "$arg" in
        --apply)    DRY_RUN=false ;;
        --show-all) SHOW_ALL=true ;;
        --fqdn)     USE_FQDN=true ;;
    esac
done

log_info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

get_technitium_leases() {
    local resp
    resp=$(curl -sf "${TECHNITIUM_URL}/api/dhcp/leases/list?token=${TECHNITIUM_TOKEN}")
    echo "$resp" | jq -c --arg suffix "$DOMAIN_SUFFIX" '
        [.response.leases[] | select(.hardwareAddress != null) | {
            mac: (.hardwareAddress | gsub("-"; ":") | ascii_downcase),
            hostname: (if .hostName == null then "" else (.hostName | rtrimstr($suffix)) end),
            hostname_fqdn: (.hostName // ""),
            ip: (.address // ""),
            scope: (.scope // "")
        }]'
}

get_unifi_clients() {
    local cmd='var c=db.user.find({mac:{$exists:true,$ne:null}},{mac:1,name:1,hostname:1,_id:0}).toArray();print(JSON.stringify(c));'
    echo "$cmd" | ssh -T "$UNIFI_SSH_HOST" "mongo --quiet --port ${UNIFI_MONGO_PORT} ${UNIFI_MONGO_DB}"
}

perform_sync() {
    local tech="$1"
    local unifi="$2"
    
    local sync_data
    sync_data=$(jq -n --arg fq "$USE_FQDN" --argjson t "$tech" --argjson u "$unifi" '
        ($t | map(select(.hostname != "")) | INDEX(.mac)) as $tm |
        [ $u[] | .mac as $m | ($tm[$m] // null) as $match |
          (if $fq == "true" then ($match.hostname_fqdn // "") else ($match.hostname // "") end) as $target |
          { mac: $m, current: (.name // ""), target: $target, ip: ($match.ip // ""), 
            needs_update: ($match != null and $target != "" and $target != (.name // "")) }
        ]')

    local updated
    updated=$(echo "$sync_data" | jq '[.[] | select(.needs_update)] | length')

    echo -e "${BOLD}UniFi <-> Technitium Sync${NC}"
    [[ "$DRY_RUN" == "true" ]] && echo -e "${YELLOW}DRY-RUN Modus${NC}" || echo -e "${RED}APPLY Modus${NC}"

    if [[ "$updated" -gt 0 ]]; then
        echo -e "\n${GREEN}Updates:${NC}"
        echo "$sync_data" | jq -r '.[] | select(.needs_update) | "\(.mac) | \(.current) | -> | \(.target)"' | column -t -s '|'
        
        if [[ "$DRY_RUN" == "false" ]]; then
            # Fix: $set in Anführungszeichen setzen
            local bulk
            bulk=$(echo "$sync_data" | jq -c '[.[] | select(.needs_update) | {updateOne:{filter:{mac:.mac},update:{"$set":{name:.target,display_name:.target,hostname:.target,note:"Sync"}}}}]')
            
            # Fix: Den gesamten Befehl in Single-Quotes an MongoDB übergeben
            local mongo_cmd="var ops=${bulk}; var res=db.user.bulkWrite(ops); print('SUCCESS|' + res.modifiedCount);"
            
            local res
            res=$(echo "$mongo_cmd" | ssh -T "$UNIFI_SSH_HOST" "mongo --quiet --port ${UNIFI_MONGO_PORT} ${UNIFI_MONGO_DB}")
            
            if echo "$res" | grep -q "SUCCESS"; then
                log_ok "Update erfolgreich: $(echo "$res" | cut -d'|' -f2) Geräte geändert."
            else
                log_error "Fehler beim DB-Update: $res"
            fi
            
            if [[ "$RESTART_UNIFI" == "true" ]]; then
                log_info "Starte UniFi Service neu..."
                ssh -n "$UNIFI_SSH_HOST" "service unifi restart"
            fi
        fi
    else
        log_ok "Alles bereits aktuell."
    fi
}

main() {
    local t_leases u_clients
    t_leases=$(get_technitium_leases)
    u_clients=$(get_unifi_clients)
    perform_sync "$t_leases" "$u_clients"
}

main "$@"
