# -----------------------------------------------------------
# Benachrichtigung wenn SSH-Login
# /opt/shell-login.sh
# -----------------------------------------------------------

#!/bin/bash

# Gotify Server URL und API-Token
GOTIFY_URL="https://gotify.yourdomain.de"
API_TOKEN="your-api-token"

# Hostname speichern
HOSTNAME=$(hostname)

TITLE="SSH-Login Verbindung"
MESSAGE="Der User $USER hat eine SSH-Verbindung zu dem Host $HOSTNAME hergestellt."
PRIORITY=10

# Nachricht an Gotify senden
curl -X POST "$GOTIFY_URL/message?token=$API_TOKEN" \
  -F "title=$TITLE" \
  -F "message=$MESSAGE" \
  -F "priority=$PRIORITY"
