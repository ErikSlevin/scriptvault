#!/bin/bash
# ============================================================
#  Cults3D Design Performance Monitor -> InfluxDB 1.x
#  Laeuft per Systemd Timer taeglich auf dem Grafana-Host
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/cults3d-monitor.conf"

# ── Config laden ──────────────────────────────────────────────────────────────

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[FEHLER] Config nicht gefunden: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# ── GraphQL Abfrage ───────────────────────────────────────────────────────────

GRAPHQL_URL="https://cults3d.com/graphql"

graphql_query() {
    local query="$1"
    local response

    response=$(curl -s -f -X POST "$GRAPHQL_URL" \
        -u "${CULTS_USERNAME}:${CULTS_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"query\": $(echo "$query" | jq -Rs .)}" \
        2>&1)

    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "[FEHLER] API-Request fehlgeschlagen (curl exit $exit_code)" >&2
        echo "$response" >&2
        return 1
    fi

    # GraphQL-Fehler pruefen
    local errors
    errors=$(echo "$response" | jq -r '.errors[]?.message // empty' 2>/dev/null)
    if [ -n "$errors" ]; then
        echo "[GraphQL-Fehler]" >&2
        echo "$errors" >&2
        return 1
    fi

    echo "$response"
}

# ── InfluxDB schreiben ────────────────────────────────────────────────────────

influx_write() {
    local line_data="$1"

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${INFLUX_URL}:${INFLUX_PORT}/write?db=${INFLUX_DB}&precision=s" \
        -u "${INFLUX_USER}:${INFLUX_PASS}" \
        --data-binary "$line_data")

    if [ "$http_code" != "204" ]; then
        echo "[FEHLER] InfluxDB write fehlgeschlagen (HTTP $http_code)" >&2
        return 1
    fi
}

influx_ensure_db() {
    curl -s -o /dev/null \
        -X POST "${INFLUX_URL}:${INFLUX_PORT}/query" \
        -u "${INFLUX_USER}:${INFLUX_PASS}" \
        --data-urlencode "q=CREATE DATABASE ${INFLUX_DB}" 2>/dev/null || true
}

# ── Designs abrufen + schreiben ───────────────────────────────────────────────

fetch_and_write_designs() {
    echo "[1/2] Designs abrufen..."

    local query='{
      myself {
        creationsBatch(limit: 50, offset: 0) {
          total
          results {
            name(locale: DE)
            shortUrl
            viewsCount
            likesCount
            downloadsCount
            price(currency: EUR) { cents }
            totalSalesAmount(currency: EUR) { cents }
            category { name(locale: DE) }
            discount { percentage endAt }
          }
        }
      }
    }'

    local response
    response=$(graphql_query "$query") || return 1

    local count
    count=$(echo "$response" | jq '.data.myself.creationsBatch.results | length')
    echo "      $count Designs gefunden."

    local now
    now=$(date +%s)

    local line_data=""

    # Jedes Design als InfluxDB Line Protocol
    while IFS= read -r design; do
        local name slug category views likes downloads price_cents sales_cents discount_pct

        name=$(echo "$design" | jq -r '.name // "unknown"')
        slug=$(echo "$design" | jq -r '.shortUrl // ""' | sed 's|/$||' | awk -F/ '{print $NF}')
        category=$(echo "$design" | jq -r '.category.name // "unknown"')
        views=$(echo "$design" | jq -r '.viewsCount // 0')
        likes=$(echo "$design" | jq -r '.likesCount // 0')
        downloads=$(echo "$design" | jq -r '.downloadsCount // 0')
        price_cents=$(echo "$design" | jq -r '.price.cents // 0')
        sales_cents=$(echo "$design" | jq -r '.totalSalesAmount.cents // 0')
        discount_pct=$(echo "$design" | jq -r '.discount.percentage // 0')

        # Sonderzeichen escapen fuer Line Protocol (Leerzeichen, Komma, Gleichzeichen in Tags)
        local escaped_name escaped_slug escaped_category
        escaped_name=$(echo "$name" | sed 's/ /\\ /g; s/,/\\,/g; s/=/\\=/g')
        escaped_slug=$(echo "$slug" | sed 's/ /\\ /g; s/,/\\,/g; s/=/\\=/g')
        escaped_category=$(echo "$category" | sed 's/ /\\ /g; s/,/\\,/g; s/=/\\=/g')

        line_data+="cults3d_design,name=${escaped_name},slug=${escaped_slug},category=${escaped_category} views=${views}i,likes=${likes}i,downloads=${downloads}i,price_cents=${price_cents}i,total_sales_cents=${sales_cents}i,discount_pct=${discount_pct}i ${now}"
        line_data+=$'\n'

    done < <(echo "$response" | jq -c '.data.myself.creationsBatch.results[]')

    if [ -n "$line_data" ]; then
        influx_write "$line_data"
        echo "[OK] $count Design-Metriken nach InfluxDB geschrieben."
    fi
}

# ── Sales abrufen + schreiben ─────────────────────────────────────────────────

fetch_and_write_sales() {
    echo "[2/2] Verkaeufe abrufen..."

    local query='query {
      myself {
        salesBatch(limit: 50, offset: 0) {
          total
          results {
            id
            creation { name(locale: DE) }
            user { nick }
            income(currency: EUR) { cents }
            createdAt
            payedOutAt
          }
        }
      }
    }'

    local response
    response=$(graphql_query "$query") || return 1

    local count
    count=$(echo "$response" | jq '.data.myself.salesBatch.results | length')
    echo "      $count Verkaeufe geladen."

    local line_data=""

    while IFS= read -r sale; do
        local creation buyer income_cents created_at payed_out sale_ts

        creation=$(echo "$sale" | jq -r '.creation.name // "unknown"')
        buyer=$(echo "$sale" | jq -r '.user.nick // "unknown"')
        income_cents=$(echo "$sale" | jq -r '.income.cents // 0')
        created_at=$(echo "$sale" | jq -r '.createdAt // ""')
        payed_out=$(echo "$sale" | jq -r 'if .payedOutAt then 1 else 0 end')

        # Timestamp konvertieren
        sale_ts=$(date -d "$created_at" +%s 2>/dev/null || date +%s)

        local escaped_creation escaped_buyer
        escaped_creation=$(echo "$creation" | sed 's/ /\\ /g; s/,/\\,/g; s/=/\\=/g')
        escaped_buyer=$(echo "$buyer" | sed 's/ /\\ /g; s/,/\\,/g; s/=/\\=/g')

        line_data+="cults3d_sale,creation=${escaped_creation},buyer=${escaped_buyer} income_cents=${income_cents}i,payed_out=${payed_out}i ${sale_ts}"
        line_data+=$'\n'

    done < <(echo "$response" | jq -c '.data.myself.salesBatch.results[]')

    if [ -n "$line_data" ]; then
        influx_write "$line_data"
        echo "[OK] $count Sales-Metriken nach InfluxDB geschrieben."
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

echo "============================================================"
echo "  Cults3D Monitor -> InfluxDB  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo ""

# Pruefen ob jq installiert ist
if ! command -v jq &>/dev/null; then
    echo "[FEHLER] 'jq' ist nicht installiert. Bitte installieren: apt install jq"
    exit 1
fi

# DB anlegen falls noetig
influx_ensure_db

# Daten abrufen und schreiben
fetch_and_write_designs
echo ""
fetch_and_write_sales

echo ""
echo "[FERTIG]"
