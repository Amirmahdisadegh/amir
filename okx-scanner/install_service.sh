#!/usr/bin/env bash
# Install the scanner as a systemd service: auto-restart on crash, survives
# reboots, logs to journald. Run from the project dir:  bash install_service.sh
set -euo pipefail
cd "$(dirname "$0")"
DIR="$(pwd)"
PY="$DIR/.venv/bin/python"
USER_NAME="$(id -un)"

if [ ! -x "$PY" ]; then
  echo "ERROR: $PY not found. Run 'make install' first."
  exit 1
fi

# stop any nohup instance so we don't run two scanners
pkill -f "main.py scan" 2>/dev/null || true

UNIT=/etc/systemd/system/okx-scanner.service
echo "Writing $UNIT ..."
sudo tee "$UNIT" >/dev/null <<EOF
[Unit]
Description=OKX RTM Scanner
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${USER_NAME}
WorkingDirectory=${DIR}
ExecStart=${PY} main.py scan
Restart=on-failure
RestartSec=10
StartLimitIntervalSec=300
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now okx-scanner
sleep 3
echo
sudo systemctl status okx-scanner --no-pager -l | head -n 12 || true
echo
echo "Done. The scanner now auto-starts on boot and auto-restarts on crash."
echo "  live logs:   journalctl -u okx-scanner -f"
echo "  restart:     sudo systemctl restart okx-scanner"
echo "  stop:        sudo systemctl stop okx-scanner"
