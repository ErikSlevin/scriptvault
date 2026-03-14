#!/bin/bash
set -e
INSTALL_DIR="/opt/cults3d-monitor"
echo "=========================================="
echo "  Cults3D Monitor - Installation"
echo "=========================================="
echo ""
if ! command -v jq &>/dev/null; then
    echo "[1/4] jq installieren..."
    apt-get update -qq && apt-get install -y -qq jq
else
    echo "[1/4] jq bereits vorhanden."
fi
echo "[2/4] Dateien nach $INSTALL_DIR kopieren..."
mkdir -p "$INSTALL_DIR"
cp cults3d-monitor.sh "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/cults3d-monitor.sh"
if [ ! -f "$INSTALL_DIR/cults3d-monitor.conf" ]; then
    cp cults3d-monitor.conf "$INSTALL_DIR/"
    chmod 600 "$INSTALL_DIR/cults3d-monitor.conf"
    echo ""
    echo "  WICHTIG: Config anpassen!"
    echo "  nano $INSTALL_DIR/cults3d-monitor.conf"
    echo "  -> CULTS_USERNAME eintragen"
    echo ""
else
    echo "  Config existiert bereits, wird nicht ueberschrieben."
fi
echo "[3/4] Systemd Service + Timer installieren..."
cp cults3d-monitor.service /etc/systemd/system/
cp cults3d-monitor.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now cults3d-monitor.timer
echo "[4/4] Timer aktiviert."
echo ""
systemctl status cults3d-monitor.timer --no-pager || true
echo ""
echo "=========================================="
echo "  Installation abgeschlossen!"
echo "=========================================="
echo ""
echo "  Naechste Schritte:"
echo "  1. Config:    nano $INSTALL_DIR/cults3d-monitor.conf"
echo "  2. Testlauf:  $INSTALL_DIR/cults3d-monitor.sh"
echo "  3. Timer:     systemctl status cults3d-monitor.timer"
echo "  4. Logs:      journalctl -u cults3d-monitor.service"
echo ""
