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

read -rp "Your capital in USDT (e.g. 10): " EQ
read -rp "Risk % per trade (1 or 2): " RISK
read -rp "OKX API Key: " OKX_KEY
read -rsp "OKX Secret Key (hidden): " OKX_SECRET; echo
read -rsp "OKX Passphrase (hidden): " OKX_PASS; echo

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
nohup .venv/bin/python main.py scan >/dev/null 2>&1 &
sleep 3
echo "Scanner restarted in Mode 2 (DEMO). Recent log:"
tail -n 15 logs/okx-scanner.log 2>/dev/null || true
echo
echo "Done. It is trading on OKX DEMO (paper money)."
echo "Watch alerts in Telegram. Stop with:  pkill -f 'main.py scan'"
