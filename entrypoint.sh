#!/bin/bash
# OTTLI Bot Entrypoint — Fully Powered by Rust Bridge

VAULT="/root/.config/.sys_pulse_cache.bin"

# ── Register only if vault doesn't exist yet ──────────────────────────────────
# Previously registered on every startup — caused infinite re-registration loop
# when the bot crashed, because each register overwrites the vault with a new
# keypair, making the old MongoDB-bound public key permanently invalid.
if [ ! -f "$VAULT" ]; then
    echo "🛡️ First run — Initializing Secure Enclave..."
    /app/shark-bridge-exe --register "$VERCEL_URL" "$API_KEY"
    if [ $? -ne 0 ]; then
        echo "❌ Registration failed. Check VERCEL_URL and API_KEY."
        exit 1
    fi
    echo "✅ Vault created."
else
    echo "🔐 Vault found — skipping registration."
fi

echo "🌊 Starting qBittorrent WebUI on port 8080..."
qbittorrent-nox --webui-port=8080 -d 2>/dev/null &
sleep 2

# Store credentials then wipe from environment
V_URL="$VERCEL_URL"
A_KEY="$API_KEY"
unset VERCEL_URL
unset API_KEY

echo "🤖 Starting OTTLI Bot via Rust Enclave..."
exec /app/shark-bridge-exe "$V_URL" "$A_KEY" "run.py"