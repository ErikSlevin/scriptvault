#!/bin/bash
NPM="http://npm.home.intern:81"
USER="xxxxxxxxxxxx@outlook.de"
PASS='xxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
CF_ZONE="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
CF_TOKEN="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

BOLD='\033[1m'; RESET='\033[0m'; DIM='\033[2m'
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'
BLUE='\033[34m'; WHITE='\033[97m'; GRAY='\033[90m'
MAGENTA='\033[35m'

TOTAL=116
dashes() { printf '─%.0s' $(seq 1 $1); }
TOP_PROXY="┌─ PROXY HOSTS $(dashes $((TOTAL - 16 - 1)))┐"
TOP_REDIR="┌─ REDIRECTION HOSTS $(dashes $((TOTAL - 21 - 1)))┐"
TOP_DNS="┌─ CLOUDFLARE DNS $(dashes $((TOTAL - 19 - 1)))┐"
BOTTOM="└$(dashes $((TOTAL - 2)))┘"
SEP="  $(dashes $((TOTAL - 4)))"

CHALLENGE=$(curl -s -X POST "$NPM/api/tokens" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$USER\",\"secret\":\"$PASS\"}" \
  | jq -r '.challenge_token')

if [[ -z "$CHALLENGE" || "$CHALLENGE" == "null" ]]; then
  echo -e "${YELLOW}⚠ Challenge fehlgeschlagen${RESET}"; exit 1
fi

# read -p "OTP-Code: " OTP
OTP=$(oathtool --totp -b "JWZ4WTIWEZW67OS64MQ7K7DZR2ELVBIT")

TOKEN=$(curl -s -X POST "$NPM/api/tokens/2fa" \
  -H "Content-Type: application/json" \
  -d "{\"challenge_token\":\"$CHALLENGE\",\"code\":\"$OTP\"}" \
  | jq -r '.token')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo -e "${YELLOW}⚠ 2FA fehlgeschlagen${RESET}"; exit 1
fi

CERTS=$(curl -s "$NPM/api/nginx/certificates" -H "Authorization: Bearer $TOKEN")
PROXY=$(curl -s "$NPM/api/nginx/proxy-hosts"  -H "Authorization: Bearer $TOKEN")
REDIR=$(curl -s "$NPM/api/nginx/redirection-hosts" -H "Authorization: Bearer $TOKEN")
DNS=$(curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE/dns_records?per_page=100" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json")

# ── Proxy Hosts ───────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${CYAN}${TOP_PROXY}${RESET}"
printf "${BOLD}${WHITE}  %-30s %-35s %-6s %-30s %-6s${RESET}\n" "DOMAIN" "BACKEND" "PORT" "ZERTIFIKAT" "STATUS"
echo -e "${GRAY}${SEP}${RESET}"

echo "$PROXY" | jq -r --argjson certs "$CERTS" '
  .[] |
  (.certificate_id // 0) as $cid |
  (if $cid > 0 then ($certs[] | select(.id == $cid) | .nice_name // .domain_names[0]) else "–" end) as $cert |
  (.enabled | if (. == 1 or . == true) then "✓" else "✗" end) as $status |
  [.domain_names[0], (.forward_scheme+"://"+.forward_host), (.forward_port|tostring), $cert, $status] | @tsv
' | while IFS=$'\t' read -r domain backend port cert status; do
  if [[ "$status" == "✓" ]]; then sc="${GREEN}✓${RESET}"; else sc="${YELLOW}✗${RESET}"; fi
  printf "  ${CYAN}%-30s${RESET} ${DIM}%-35s${RESET} %-6s %-30s $sc\n" "$domain" "$backend" "$port" "$cert"
done

echo -e "${BOLD}${CYAN}${BOTTOM}${RESET}"

# ── Redirection Hosts ─────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${BLUE}${TOP_REDIR}${RESET}"
printf "${BOLD}${WHITE}  %-30s %-6s %-40s %-6s${RESET}\n" "DOMAIN" "CODE" "ZIEL" "STATUS"
echo -e "${GRAY}${SEP}${RESET}"

echo "$REDIR" | jq -r '.[] |
  [.domain_names[0], (.forward_http_code|tostring),
   (.forward_scheme+"://"+.forward_domain_name),
   (.enabled | if (. == 1 or . == true) then "✓" else "✗" end)] | @tsv' \
| while IFS=$'\t' read -r domain code ziel status; do
  if [[ "$status" == "✓" ]]; then sc="${GREEN}✓${RESET}"; else sc="${YELLOW}✗${RESET}"; fi
  printf "  ${BLUE}%-30s${RESET} ${YELLOW}%-6s${RESET} ${DIM}%-40s${RESET} $sc\n" "$domain" "$code" "$ziel"
done

echo -e "${BOLD}${BLUE}${BOTTOM}${RESET}"

# ── Cloudflare DNS ────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${MAGENTA}${TOP_DNS}${RESET}"
printf "${BOLD}${WHITE}  %-6s %-35s %-70s${RESET}\n" "TYP" "NAME" "INHALT"
echo -e "${GRAY}${SEP}${RESET}"

echo "$DNS" | jq -r '.result[] | [.type, .name, .content] | @tsv' \
| while IFS=$'\t' read -r type name content; do
  case "$type" in
    A)     tc="${GREEN}"   ;;
    AAAA)  tc="${CYAN}"    ;;
    CNAME) tc="${BLUE}"    ;;
    MX)    tc="${YELLOW}"  ;;
    TXT)   tc="${DIM}"     ;;
    CAA)   tc="${MAGENTA}" ;;
    *)     tc="${WHITE}"   ;;
  esac
  printf "  ${tc}%-6s${RESET} ${MAGENTA}%-35s${RESET} ${DIM}%-70s${RESET}\n" "$type" "$name" "$content"
done

echo -e "${BOLD}${MAGENTA}${BOTTOM}${RESET}"
echo
