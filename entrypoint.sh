#!/bin/bash
# OTTLI Bot Entrypoint — Fully Powered by Rust Bridge

VAULT="/root/.config/.sys_pulse_cache.bin"

# ── Register only if vault doesn't exist yet ──────────────────────────────────
# Previously registered on every startup — caused infinite re-registration loop
# when the bot crashed, because each register overwrites the vault with a new
# keypair, making the old MongoDB-bound public key permanently invalid.
# Start qBittorrent early — needs time to bind port 8080 before the bot queries it
echo "🌊 Starting qBittorrent WebUI on port 8080..."
qbittorrent-nox --confirm-legal-notice --webui-port=8080 -d 2>/dev/null &
sleep 3

FAIL_SENTINEL="/root/.config/.reg_failed.lock"

if [ -f "$FAIL_SENTINEL" ]; then
    echo "❌ Registration previously failed — not retrying to avoid API limit hits."
    echo "   Delete $FAIL_SENTINEL and fix your VERCEL_URL/API_KEY, then redeploy."
    exit 1
fi

if [ ! -f "$VAULT" ]; then
    echo "🛡️ First run — Initializing Secure Enclave..."
    /app/shark-bridge-exe --register "$VERCEL_URL" "$API_KEY"
    if [ $? -ne 0 ]; then
        echo "❌ Registration failed. Check VERCEL_URL and API_KEY."
        touch "$FAIL_SENTINEL"   # stop future restarts from hammering Vercel
        exit 1
    fi
    echo "✅ Vault created."
else
    echo "🔐 Vault found — skipping registration."
fi

# Store credentials then wipe from environment —
# unset happens in this shell only; exec replaces the process so
# the child never inherits the originals regardless. Safe to wipe here.
V_URL="$VERCEL_URL"
A_KEY="$API_KEY"
unset VERCEL_URL
unset API_KEY

echo "🤖 Starting OTTLI Bot via Rust Enclave..."
exec /app/shark-bridge-exe "$V_URL" "$A_KEY" "run.py"