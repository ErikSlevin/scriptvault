#!/bin/bash
###############################################################################
# unifi-technitium-sync.sh
#
# Gleicht UniFi-Clients mit Technitium DHCP-Leases ab:
#   - Setzt Hostnamen aus Technitium in UniFi
#   - Proxmox-Clients: Gruppen-Zuweisung + Server-Icon (dev_id_override 5254)
#   - Cleanup: Löscht alte Clients (>7 Tage nicht gesehen)
#
# Nutzung:
#   ./unifi-technitium-sync.sh                        # Dry-Run
#   ./unifi-technitium-sync.sh --apply                # Sync anwenden
#   ./unifi-technitium-sync.sh --apply --fqdn         # Mit Domain-Suffix
#   ./unifi-technitium-sync.sh --cleanup              # Dry-Run alte Clients
#   ./unifi-technitium-sync.sh --apply --cleanup      # Sync + Cleanup
#   ./unifi-technitium-sync.sh --show-all             # Alle Clients zeigen
###############################################################################
set -euo pipefail

# ========================== KONFIGURATION ==========================
TECHNITIUM_URL="http://dns.home.intern:5380"
TECHNITIUM_TOKEN="dab4f2dec5933a5766fc8b72bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
UNIFI_SSH_HOST="unifi"
UNIFI_MONGO_PORT="27117"
UNIFI_MONGO_DB="ace"
DOMAIN_SUFFIX=".home.intern"

# Proxmox-Features
PROXMOX_GROUP_ID="689247c7d3d4080f26122b2a"
PROXMOX_DEV_ID=5254
SET_SERVER_ICON=true

# Cleanup: Clients die länger als X Tage nicht gesehen wurden
CLEANUP_DAYS=7

# UniFi Neustart nach Apply
RESTART_UNIFI=true

# Optionale Config-Datei laden
CONFIG_FILE="${HOME}/.config/unifi-technitium-sync.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi
# ===================================================================

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# Flags
DRY_RUN=true
SHOW_ALL=false
USE_FQDN=false
DO_CLEANUP=false

for arg in "$@"; do
    case "$arg" in
        --apply)    DRY_RUN=false ;;
        --show-all) SHOW_ALL=true ;;
        --fqdn)     USE_FQDN=true ;;
        --cleanup)  DO_CLEANUP=true ;;
        --help|-h)
            echo "Nutzung: $0 [--apply] [--show-all] [--fqdn] [--cleanup]"
            echo ""
            echo "  --apply     Änderungen in UniFi MongoDB schreiben"
            echo "  --show-all  Alle Clients anzeigen (auch ohne Match)"
            echo "  --fqdn      Hostnamen mit Domain-Suffix (z.B. grafana${DOMAIN_SUFFIX})"
            echo "  --cleanup   Alte Clients löschen (>${CLEANUP_DAYS} Tage nicht gesehen)"
            exit 0
            ;;
        *)
            echo -e "${RED}Unbekanntes Argument: $arg${NC}"
            exit 1
            ;;
    esac
done

# ========================== HILFSFUNKTIONEN ==========================

log_info()  { echo -e "${CYAN}[INFO]${NC}  $*" >&2; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_deps() {
    local missing=()
    for cmd in jq curl ssh column; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Fehlende Abhängigkeiten: ${missing[*]}"
        exit 1
    fi
}

# Führt ein JS-Script auf der UniFi MongoDB aus (via temp file, umgeht Zeilenlimit)
run_mongo_script() {
    local script_content="$1"
    local remote_script="/tmp/unifi-sync-$$.js"

    echo "$script_content" | ssh -T "$UNIFI_SSH_HOST" "cat > ${remote_script}" 2>/dev/null
    ssh -n "$UNIFI_SSH_HOST" "mongo --quiet --port ${UNIFI_MONGO_PORT} ${UNIFI_MONGO_DB} ${remote_script}; rm -f ${remote_script}" 2>&1
}

# ========================== DATENBESCHAFFUNG ==========================

get_technitium_data() {
    log_info "Hole Technitium DHCP Daten..."

    # 1. Alle aktiven Leases holen
    local leases_response
    leases_response=$(curl -sf "${TECHNITIUM_URL}/api/dhcp/leases/list?token=${TECHNITIUM_TOKEN}") || {
        log_error "Technitium API nicht erreichbar: ${TECHNITIUM_URL}"
        exit 1
    }

    if [[ "$(echo "$leases_response" | jq -r '.status // empty')" != "ok" ]]; then
        log_error "Technitium API Fehler: $(echo "$leases_response" | jq -r '.errorMessage // "Unbekannt"')"
        exit 1
    fi

    # Leases normalisieren
    local leases
    leases=$(echo "$leases_response" | jq -c --arg suffix "$DOMAIN_SUFFIX" '
        [.response.leases[] | select(.hardwareAddress != null) | {
            mac:      (.hardwareAddress | gsub("-"; ":") | ascii_downcase),
            hostname: (if .hostName == null then "" else (.hostName | rtrimstr($suffix)) end),
            hostname_fqdn: (.hostName // ""),
            ip:       (.address // ""),
            scope:    (.scope // ""),
            source:   "lease"
        }]')

    local lease_count
    lease_count=$(echo "$leases" | jq 'length')
    log_info "  Leases: ${lease_count}"

    # 2. Alle Scope-Namen holen
    local scopes_response
    scopes_response=$(curl -sf "${TECHNITIUM_URL}/api/dhcp/scopes/list?token=${TECHNITIUM_TOKEN}") || {
        log_warn "Konnte Scope-Liste nicht abrufen"
        echo "$leases"
        return
    }

    local scope_names
    scope_names=$(echo "$scopes_response" | jq -r '.response.scopes[]?.name // empty')

    # 3. Pro Scope die Reservierungen holen
    local all_reservations="[]"

    while IFS= read -r scope; do
        [[ -z "$scope" ]] && continue

        local scope_response
        scope_response=$(curl -sf "${TECHNITIUM_URL}/api/dhcp/scopes/get?token=${TECHNITIUM_TOKEN}&name=${scope}" 2>/dev/null) || continue

        local reservations
        reservations=$(echo "$scope_response" | jq -c --arg scope "$scope" --arg suffix "$DOMAIN_SUFFIX" '
            [(.response.reservedLeases // [])[] | select(.hardwareAddress != null) | {
                mac:      (.hardwareAddress | gsub("-"; ":") | ascii_downcase),
                hostname: (if .hostName == null or .hostName == "" then "" else (.hostName | rtrimstr($suffix)) end),
                hostname_fqdn: (if .hostName == null or .hostName == "" then ""
                               elif (.hostName | endswith($suffix)) then .hostName
                               else (.hostName + $suffix) end),
                ip:       (.address // ""),
                scope:    $scope,
                source:   "reservation"
            }]')

        local res_count
        res_count=$(echo "$reservations" | jq 'length')
        [[ "$res_count" -gt 0 ]] && log_info "  Reservierungen ${scope}: ${res_count}"

        all_reservations=$(echo "$all_reservations" "$reservations" | jq -s '.[0] + .[1]')
    done <<< "$scope_names"

    # 4. Mergen: Leases haben Priorität (aktuellere Daten), Reservierungen als Fallback
    # GROUP BY mac: Wenn Lease existiert → Lease nehmen, sonst Reservierung
    jq -n -c \
        --argjson leases "$leases" \
        --argjson reservations "$all_reservations" '
        ($leases | INDEX(.mac)) as $lease_map |
        ($reservations | INDEX(.mac)) as $res_map |
        # Alle MACs zusammenführen
        ([$leases[].mac, $reservations[].mac] | unique) as $all_macs |
        [$all_macs[] as $mac |
            if $lease_map[$mac] != null then $lease_map[$mac]
            else $res_map[$mac]
            end
        | select(.hostname != "")]
    '
}

get_unifi_clients() {
    log_info "Hole UniFi Clients via MongoDB..."
    local mongo_output
    mongo_output=$(ssh -T "$UNIFI_SSH_HOST" "mongo --quiet --port ${UNIFI_MONGO_PORT} ${UNIFI_MONGO_DB}" <<'MONGOEOF' 2>/dev/null
var c = db.user.find(
    { mac: { $exists: true, $ne: null } },
    { mac:1, name:1, hostname:1, display_name:1, oui:1,
      network_members_group_ids:1, dev_family:1, dev_id_override:1,
      last_seen:1, first_seen:1, _id:0 }
).toArray();
print(JSON.stringify(c));
MONGOEOF
    ) || {
        log_error "UniFi MongoDB nicht erreichbar (ssh ${UNIFI_SSH_HOST})"
        exit 1
    }

    if ! echo "$mongo_output" | jq empty 2>/dev/null; then
        log_error "Ungültiges JSON von UniFi MongoDB"
        exit 1
    fi

    log_ok "$(echo "$mongo_output" | jq 'length') UniFi Clients geladen"
    echo "$mongo_output"
}

# ========================== SYNCHRONISATION ==========================

perform_sync() {
    local tech="$1"
    local unifi="$2"

    local now_epoch
    now_epoch=$(date +%s)
    local cutoff_epoch=$((now_epoch - CLEANUP_DAYS * 86400))

    local sync_data
    sync_data=$(jq -n \
        --arg use_fqdn "$USE_FQDN" \
        --arg p_id "$PROXMOX_GROUP_ID" \
        --argjson p_dev_id "$PROXMOX_DEV_ID" \
        --arg set_icon "$SET_SERVER_ICON" \
        --argjson cutoff "$cutoff_epoch" \
        --argjson t "$tech" \
        --argjson u "$unifi" '

        ($t | map(select(.hostname != "")) | INDEX(.mac)) as $tm |

        # Helper: MongoDB NumberLong ({"$numberLong":"..."}) oder plain number → number
        def numval: if type == "object" then (.["$numberLong"] // "0") | tonumber elif type == "string" then tonumber else . end;

        [ $u[] | .mac as $m | ($tm[$m] // null) as $match |

          # Ziel-Name je nach --fqdn
          (if $use_fqdn == "true"
           then ($match.hostname_fqdn // "")
           else ($match.hostname // "")
           end) as $target_name |

          # Proxmox-Erkennung
          (.oui == "Proxmox Server Solutions GmbH") as $is_proxmox |
          (.network_members_group_ids // []) as $current_groups |
          ($current_groups | contains([$p_id])) as $already_in_group |

          # Icon + dev_id Logik
          (if $is_proxmox and $set_icon == "true"
           then "Server" else (.dev_family // "") end) as $target_family |
          ((.dev_id_override // 0) | numval) as $current_dev_id |
          (if $is_proxmox
           then $p_dev_id else $current_dev_id end) as $target_dev_id |

          # Alter berechnen
          ((.last_seen // 0) | numval) as $last |

          {
            mac:            $m,
            current_name:   (.name // ""),
            target_name:    (if $target_name != "" then $target_name else (.name // "") end),
            tech_ip:        ($match.ip // ""),
            tech_scope:     ($match.scope // ""),
            is_proxmox:     $is_proxmox,
            has_tech_match: ($match != null),
            target_groups:  (if $is_proxmox and ($already_in_group | not)
                            then ($current_groups + [$p_id])
                            else $current_groups end),
            target_family:  $target_family,
            target_dev_id:  $target_dev_id,
            last_seen:      $last,
            is_stale:       ($last > 0 and $last < $cutoff),

            # Gründe für Update
            name_changed:   ($target_name != "" and $target_name != (.name // "")),
            group_changed:  ($is_proxmox and ($already_in_group | not)),
            icon_changed:   ($is_proxmox and $set_icon == "true" and (
                              (.dev_family // "") != "Server" or
                              $current_dev_id != $p_dev_id
                            )),
            needs_update:   (
              ($target_name != "" and $target_name != (.name // "")) or
              ($is_proxmox and ($already_in_group | not)) or
              ($is_proxmox and $set_icon == "true" and (
                (.dev_family // "") != "Server" or
                $current_dev_id != $p_dev_id
              ))
            )
          }
        ] | sort_by(.mac)
    ')

    # Statistiken
    local total updated no_match name_changes group_changes icon_changes stale_count
    total=$(echo "$sync_data" | jq 'length')
    updated=$(echo "$sync_data" | jq '[.[] | select(.needs_update)] | length')
    no_match=$(echo "$sync_data" | jq '[.[] | select(.has_tech_match | not)] | length')
    name_changes=$(echo "$sync_data" | jq '[.[] | select(.name_changed)] | length')
    group_changes=$(echo "$sync_data" | jq '[.[] | select(.group_changed)] | length')
    icon_changes=$(echo "$sync_data" | jq '[.[] | select(.icon_changed)] | length')
    stale_count=$(echo "$sync_data" | jq '[.[] | select(.is_stale)] | length')

    # ── Header ──────────────────────────────────────────────────────
    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  UniFi ←→ Technitium Sync + Proxmox Features${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    if $DRY_RUN; then
        echo -e "  ${YELLOW}${BOLD}Modus:${NC}    DRY-RUN (keine Änderungen)"
    else
        echo -e "  ${RED}${BOLD}Modus:${NC}    APPLY — Änderungen werden geschrieben!"
    fi
    echo -e "  ${CYAN}Namen:${NC}    $( $USE_FQDN && echo "FQDN (inkl. ${DOMAIN_SUFFIX})" || echo "Kurzname" )"
    echo -e "  ${CYAN}Cleanup:${NC}  $( $DO_CLEANUP && echo "Aktiv (>${CLEANUP_DAYS} Tage)" || echo "Aus" )"
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # ── Namens-Updates ──────────────────────────────────────────────
    if [[ "$name_changes" -gt 0 ]]; then
        echo -e "${GREEN}${BOLD}▸ Namens-Updates (${name_changes}):${NC}"
        echo ""
        {
            echo "MAC|NEUER NAME|ALTER NAME|IP|SCOPE"
            echo "$sync_data" | jq -r '.[] | select(.name_changed) |
                "\(.mac)|\(.target_name)|\(.current_name)|\(.tech_ip)|\(.tech_scope)"'
        } | column -t -s '|' | sed 's/^/  /'
        echo ""
    fi

    # ── Proxmox Gruppen-Updates ─────────────────────────────────────
    if [[ "$group_changes" -gt 0 ]]; then
        echo -e "${CYAN}${BOLD}▸ Proxmox Gruppen-Zuweisung (${group_changes}):${NC}"
        echo ""
        {
            echo "MAC|NAME|AKTION"
            echo "$sync_data" | jq -r '.[] | select(.group_changed) |
                "\(.mac)|\(.target_name)|→ Gruppe hinzugefügt"'
        } | column -t -s '|' | sed 's/^/  /'
        echo ""
    fi

    # ── Icon/DevID-Updates ──────────────────────────────────────────
    if [[ "$icon_changes" -gt 0 ]]; then
        echo -e "${CYAN}${BOLD}▸ Proxmox Icon + DevID (${icon_changes}):${NC}"
        echo ""
        {
            echo "MAC|NAME|DEV_FAMILY|DEV_ID"
            echo "$sync_data" | jq -r '.[] | select(.icon_changed) |
                "\(.mac)|\(.target_name)|→ Server|→ \(.target_dev_id)"'
        } | column -t -s '|' | sed 's/^/  /'
        echo ""
    fi

    # ── Cleanup: Alte Clients ───────────────────────────────────────
    if $DO_CLEANUP && [[ "$stale_count" -gt 0 ]]; then
        echo -e "${RED}${BOLD}▸ Alte Clients zum Löschen (${stale_count}, >${CLEANUP_DAYS} Tage nicht gesehen):${NC}"
        echo ""
        {
            echo "MAC|NAME|LETZTES SIGNAL|TAGE HER"
            echo "$sync_data" | jq -r --argjson now "$now_epoch" '.[] | select(.is_stale) |
                (($now - .last_seen) / 86400 | floor) as $days |
                "\(.mac)|\(.current_name)|\(.last_seen | todate)|\($days) Tage"'
        } | column -t -s '|' | sed 's/^/  /'
        echo ""
    elif $DO_CLEANUP; then
        echo -e "  ${GREEN}Keine alten Clients gefunden (alle <${CLEANUP_DAYS} Tage).${NC}"
        echo ""
    fi

    # ── Keine Änderungen ────────────────────────────────────────────
    if [[ "$updated" -eq 0 ]] && { ! $DO_CLEANUP || [[ "$stale_count" -eq 0 ]]; }; then
        echo -e "  ${GREEN}Alles synchron — keine Updates oder Löschungen notwendig.${NC}"
        echo ""
    fi

    # ── Clients ohne Match ──────────────────────────────────────────
    if $SHOW_ALL && [[ "$no_match" -gt 0 ]]; then
        echo -e "${GRAY}${BOLD}▸ UniFi-Clients ohne Technitium-Match (${no_match}):${NC}"
        echo ""
        echo "$sync_data" | jq -r '.[] | select(.has_tech_match | not) |
            "  \(.mac)  \(.current_name // "(kein Name)")"'
        echo ""
    fi

    # ── Zusammenfassung ─────────────────────────────────────────────
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  Gesamt UniFi Clients:        ${BOLD}${total}${NC}"
    echo -e "  Mit Technitium-Match:        ${BOLD}$((total - no_match))${NC}"
    echo -e "  ${GREEN}Namens-Updates:${NC}             ${BOLD}${name_changes}${NC}"
    echo -e "  ${CYAN}Gruppen-Updates:${NC}            ${BOLD}${group_changes}${NC}"
    echo -e "  ${CYAN}Icon-Updates:${NC}               ${BOLD}${icon_changes}${NC}"
    if $DO_CLEANUP; then
        echo -e "  ${RED}Zu löschen:${NC}                ${BOLD}${stale_count}${NC}"
    fi
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"

    # ── Dry-Run Hinweis ─────────────────────────────────────────────
    if $DRY_RUN && { [[ "$updated" -gt 0 ]] || { $DO_CLEANUP && [[ "$stale_count" -gt 0 ]]; }; }; then
        echo ""
        local hint="$0 --apply"
        $USE_FQDN && hint+=" --fqdn"
        $DO_CLEANUP && hint+=" --cleanup"
        echo -e "  ${YELLOW}→ Zum Anwenden:  ${hint}${NC}"
    fi

    # ── Apply: Sync ─────────────────────────────────────────────────
    local changes_made=false

    if ! $DRY_RUN && [[ "$updated" -gt 0 ]]; then
        echo ""
        log_info "Generiere MongoDB Bulk-Update (${updated} Sync-Updates)..."

        local bulk_json
        bulk_json=$(echo "$sync_data" | jq -c '
            [.[] | select(.needs_update) | {
                updateOne: {
                    filter: { mac: .mac },
                    update: { "$set": {
                        name:                       .target_name,
                        display_name:               .target_name,
                        hostname:                   .target_name,
                        network_members_group_ids:  .target_groups,
                        dev_family:                 .target_family,
                        dev_id_override:            .target_dev_id,
                        fingerprint_override:       true,
                        note:                       "Name via Technitium Sync"
                    }}
                }
            }]')

        local script_content
        script_content=$(cat <<JSEOF
var ops = ${bulk_json};
try {
    var res = db.user.bulkWrite(ops);
    print("SUCCESS|" + res.modifiedCount);
} catch(e) {
    print("ERROR|" + e);
}
JSEOF
        )

        local result
        result=$(run_mongo_script "$script_content") || true

        if echo "$result" | grep -q "^SUCCESS|"; then
            local mod_count
            mod_count=$(echo "$result" | cut -d'|' -f2)
            log_ok "${mod_count} Dokumente aktualisiert"
            changes_made=true
        else
            log_error "MongoDB Sync fehlgeschlagen: ${result}"
        fi
    fi

    # ── Apply: Cleanup ──────────────────────────────────────────────
    if ! $DRY_RUN && $DO_CLEANUP && [[ "$stale_count" -gt 0 ]]; then
        echo ""
        log_info "Lösche ${stale_count} alte Clients (>${CLEANUP_DAYS} Tage)..."

        local stale_macs
        stale_macs=$(echo "$sync_data" | jq -c '[.[] | select(.is_stale) | .mac]')

        local script_content
        script_content=$(cat <<JSEOF
var macs = ${stale_macs};
try {
    var res = db.user.deleteMany({ mac: { \$in: macs } });
    print("DELETED|" + res.deletedCount);
} catch(e) {
    print("ERROR|" + e);
}
JSEOF
        )

        local result
        result=$(run_mongo_script "$script_content") || true

        if echo "$result" | grep -q "^DELETED|"; then
            local del_count
            del_count=$(echo "$result" | cut -d'|' -f2)
            log_ok "${del_count} alte Clients gelöscht"
            changes_made=true
        else
            log_error "MongoDB Cleanup fehlgeschlagen: ${result}"
        fi
    fi

    # ── Neustart ────────────────────────────────────────────────────
    if $changes_made && $RESTART_UNIFI; then
        echo ""
        log_info "Starte UniFi Service neu..."
        if ssh -n "$UNIFI_SSH_HOST" 'service unifi restart' 2>/dev/null; then
            log_ok "UniFi Service neu gestartet"
        else
            log_warn "Neustart fehlgeschlagen — manuell: ssh ${UNIFI_SSH_HOST} 'service unifi restart'"
        fi
    fi
}

# ========================== MAIN ==========================

main() {
    echo ""
    echo -e "${BOLD}UniFi ←→ Technitium DHCP Sync${NC}"
    echo -e "${GRAY}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""

    check_deps

    local tech_leases unifi_clients

    tech_leases=$(get_technitium_data)
    log_ok "$(echo "$tech_leases" | jq 'length') Technitium Einträge geladen (Leases + Reservierungen)"

    unifi_clients=$(get_unifi_clients)

    perform_sync "$tech_leases" "$unifi_clients"
}

main "$@"
