#!/bin/bash
set -e

echo "=== Annes Kalender - Installation ==="

# System-Pakete
apt-get update -qq
apt-get install -y -qq python3 python3-pip python3-venv openssh-client

# App-Dateien nach /opt/kalender verschieben
mkdir -p /opt/kalender/templates
mv app.py /opt/kalender/
mv requirements.txt /opt/kalender/
mv templates/index.html /opt/kalender/templates/

# config.json nur verschieben wenn noch nicht vorhanden
if [ ! -f /opt/kalender/config.json ]; then
  mv config.json /opt/kalender/
  echo "  -> config.json verschoben (bitte anpassen!)"
else
  rm -f config.json
  echo "  -> config.json bereits vorhanden, wird nicht überschrieben"
fi

# Venv anlegen und Pakete installieren
python3 -m venv /opt/kalender/venv
/opt/kalender/venv/bin/pip install --quiet -r /opt/kalender/requirements.txt

# SSH-Key generieren falls noch nicht vorhanden
if [ ! -f /opt/kalender/ha_key ]; then
  ssh-keygen -t ed25519 -f /opt/kalender/ha_key -N ""
  echo ""
  echo "=== SSH Public Key (in HA eintragen!) ==="
  cat /opt/kalender/ha_key.pub
  echo "=========================================="
fi

# Systemd-Service
cat > /etc/systemd/system/kalender.service << 'SERVICE'
[Unit]
Description=Annes Kalender
After=network.target

[Service]
WorkingDirectory=/opt/kalender
ExecStart=/opt/kalender/venv/bin/uvicorn app:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable kalender
systemctl restart kalender

echo ""
echo "Installation abgeschlossen!"
echo "App laeuft auf http://$(hostname -f):8000"
echo ""
echo "Naechste Schritte:"
echo "  1. nano /opt/kalender/config.json"
echo "  2. SSH Public Key in HA eintragen: cat /opt/kalender/ha_key.pub"
echo "  3. systemctl restart kalender"
