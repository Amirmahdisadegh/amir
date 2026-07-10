#!/usr/bin/env bash
# Interactive one-shot setup for Mode 2 (auto-execution) on OKX DEMO.
# Reads secrets with hidden input (they never echo or land in shell history),
# writes .env, sets config.yaml to live+demo with your capital/risk, and
# restarts the scanner in the background. Run:  bash setup_live.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "=============================================="
echo "  OKX Mode 2 setup  (DEMO / paper trading)"
echo "=============================================="
echo "Create the API key in OKX >> Demo Trading first:"
echo "  Permission: Trade only (NO withdrawal)"
echo "  IP whitelist: 206.245.166.128"
echo

[ -f config.yaml ] || cp config.example.yaml config.yaml

# --- prompt helpers that refuse empty / invalid input ---
ask_number() {  # $1=prompt ; echoes a positive number
  local p="$1" v
  while true; do
    read -rp "$p" v
    if [[ "$v" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk "BEGIN{exit !($v>0)}"; then
      echo "$v"; return
    fi
    echo "  -> please type a number greater than 0 (e.g. 10)" >&2
  done
}
ask_text() {  # $1=prompt $2=hidden(1/0) ; echoes non-empty text
  local p="$1" hidden="$2" v
  while true; do
    if [ "$hidden" = "1" ]; then read -rsp "$p" v; echo >&2; else read -rp "$p" v; fi
    [ -n "$v" ] && { echo "$v"; return; }
    echo "  -> this cannot be empty, try again" >&2
  done
}

EQ=$(ask_number "Your capital in USDT (e.g. 10): ")
RISK=$(ask_number "Risk % per trade (1 or 2): ")
OKX_KEY=$(ask_text "OKX API Key: " 0)
OKX_SECRET=$(ask_text "OKX Secret Key (hidden): " 1)
OKX_PASS=$(ask_text "OKX Passphrase (hidden): " 1)

# --- preserve existing Telegram creds, rewrite .env cleanly (no sed on secrets) ---
TG_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' .env 2>/dev/null | cut -d= -f2- || true)
TG_CHAT=$(grep '^TELEGRAM_CHAT_ID='  .env 2>/dev/null | cut -d= -f2- || true)
umask 077
cat > .env <<EOF
TELEGRAM_BOT_TOKEN=${TG_TOKEN}
TELEGRAM_CHAT_ID=${TG_CHAT}
OKX_API_KEY=${OKX_KEY}
OKX_API_SECRET=${OKX_SECRET}
OKX_API_PASSPHRASE=${OKX_PASS}
EOF
chmod 600 .env

# --- config: live mode, DEMO sandbox (forced on for safety), capital, risk ---
sed -i 's/^mode:.*/mode: live/' config.yaml
sed -i 's/^  sandbox:.*/  sandbox: true/' config.yaml
sed -i "s/^  account_equity_usdt:.*/  account_equity_usdt: ${EQ}/" config.yaml
sed -i "s/^  risk_per_trade_pct:.*/  risk_per_trade_pct: ${RISK}/" config.yaml

echo
echo "Applied config:"
grep -E '^mode:|  sandbox:|  account_equity_usdt:|  risk_per_trade_pct:' config.yaml
echo

# --- restart scanner in background ---
pkill -f "main.py scan" 2>/dev/null || true
sleep 1
mkdir -p logs
nohup .venv/bin/python main.py scan >logs/startup.log 2>&1 &
sleep 6
echo
if pgrep -f "main.py scan" >/dev/null; then
  echo "OK: scanner is running in Mode 2 (DEMO / paper money)."
  echo "Watch alerts in Telegram. Stop with:  pkill -f 'main.py scan'"
else
  echo "WARNING: the scanner did NOT stay running — likely a bad API key."
  echo "Error output:"
  tail -n 20 logs/startup.log 2>/dev/null || true
  echo
  echo "Fix the credentials and run  bash setup_live.sh  again."
fi
