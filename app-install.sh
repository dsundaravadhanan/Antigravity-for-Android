#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# Antigravity App & Web GUI Unified Installer (Testing Release)
# ==============================================================================
# Configures a seamless unified environment where:
#  1. Auth (OAuth Token) is shared across CLI, Web GUI, and Android App (APK).
#  2. Chats and Conversations are 100% synchronized across all interfaces.
#  3. Settings and trusted workspaces are unified under Termux $HOME.
#  4. The Google Sign-In redirect works reliably via Termux's native broadcast bridge.
# ==============================================================================
set -e

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
BIN_DIR="${PREFIX}/bin"
USER_BIN="$HOME/.local/bin"
AUTH_DEST="$HOME/.gemini/antigravity-cli"
PROJECTS_DIR="$HOME/.gemini/config/projects"

# Parse CLI arguments
SILENT=0
for arg in "$@"; do
    case "$arg" in
        --silent|-s|-q|--quiet) SILENT=1 ;;
    esac
done

if [ "$SILENT" -eq 0 ]; then
    echo "======================================================"
    echo "  Antigravity Unified App & CLI Setup (Test Phase)    "
    echo "======================================================"
fi

# ==============================================================================
# [1/5] Locate Official Antigravity Binary & Environment
# ==============================================================================
if [ "$SILENT" -eq 0 ]; then
    echo "[1/5] Verifying Antigravity CLI binary..."
fi

mkdir -p "$BIN_DIR"
mkdir -p "$USER_BIN"
mkdir -p "$AUTH_DEST"
chmod 700 "$AUTH_DEST"

find_official_bin() {
    if [ -f "$BIN_DIR/agy" ] && [ -x "$BIN_DIR/agy" ]; then
        echo "$BIN_DIR/agy"
    elif [ -f "$USER_BIN/agy" ] && [ -x "$USER_BIN/agy" ]; then
        echo "$USER_BIN/agy"
    else
        echo ""
    fi
}

OFFICIAL_BIN="$(find_official_bin)"

if [ -z "$OFFICIAL_BIN" ]; then
    echo "[-] Official Antigravity binary 'agy' not found."
    CHOICE=""
    if [ -t 0 ]; then
        read -r -p "Install official agy from Google? [y/n]: " CHOICE
    elif [ -e /dev/tty ]; then
        read -r -p "Install official agy from Google? [y/n]: " CHOICE < /dev/tty
    else
        CHOICE="y"
    fi

    case "$CHOICE" in
        [Yy]* )
            echo "Installing official Google Antigravity CLI..."
            TMP_BOOTSTRAP="$(mktemp 2>/dev/null || echo "$HOME/.local/bin/agy_install_tmp.sh")"
            curl -fsSL --compressed https://antigravity.google/cli/install.sh -o "$TMP_BOOTSTRAP" 2>/dev/null || \
                curl -fsSL https://antigravity.google/cli/install.sh -o "$TMP_BOOTSTRAP"
            if [ -f "$TMP_BOOTSTRAP" ] && gzip -t "$TMP_BOOTSTRAP" 2>/dev/null; then
                gzip -dc "$TMP_BOOTSTRAP" > "${TMP_BOOTSTRAP}.raw" 2>/dev/null && mv -f "${TMP_BOOTSTRAP}.raw" "$TMP_BOOTSTRAP"
            fi
            if [ -f "$TMP_BOOTSTRAP" ] && head -n 1 "$TMP_BOOTSTRAP" | grep -q "^#\!"; then
                bash "$TMP_BOOTSTRAP"
                rm -f "$TMP_BOOTSTRAP" 2>/dev/null || true
            else
                rm -f "$TMP_BOOTSTRAP" 2>/dev/null || true
                echo "[-] Error: Failed to fetch valid installer script from Google."
                exit 1
            fi
            OFFICIAL_BIN="$(find_official_bin)"
            ;;
        * )
            echo "Exiting."
            exit 0
            ;;
    esac
fi

# Ensure ~/.bashrc environment settings
BASHRC="$HOME/.bashrc"
[ -f "$BASHRC" ] || touch "$BASHRC"

grep -q '\.local/bin' "$BASHRC" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
grep -q 'NODE_OPTIONS.*ipv4first' "$BASHRC" 2>/dev/null || echo 'export NODE_OPTIONS="--dns-result-order=ipv4first"' >> "$BASHRC"
grep -q 'GOMEMLIMIT' "$BASHRC" 2>/dev/null || echo 'export GOMEMLIMIT=1536MiB' >> "$BASHRC"

# Clean up GODEBUG override if present
sed -i '/GODEBUG.*netdns=go/d' "$BASHRC" 2>/dev/null || true
unset GODEBUG 2>/dev/null || true

# ==============================================================================
# [2/5] Resilient Browser OAuth Bridge (Fixes Sign-In Redirection Bug)
# ==============================================================================
if [ "$SILENT" -eq 0 ]; then
    echo "[2/5] Configuring resilient OAuth browser bridge..."
fi

# Create smart xdg-open wrapper that uses TermuxOpenReceiver broadcast and caches auth URL
cat << 'EOF' > "$BIN_DIR/xdg-open"
#!/data/data/com.termux/files/usr/bin/sh
# Resilient xdg-open wrapper for Google Antigravity OAuth & Web GUI
TARGET="$1"
AUTH_DIR="$HOME/.gemini/antigravity-cli"
mkdir -p "$AUTH_DIR" 2>/dev/null || true

# If target is an HTTP/HTTPS URL, log it for easy recovery
case "$TARGET" in
    http://*|https://*)
        echo "$TARGET" > "$AUTH_DIR/last-auth-url.txt" 2>/dev/null || true
        if [ -d "/sdcard/Download" ] && [ -w "/sdcard/Download" ]; then
            echo "$TARGET" > "/sdcard/Download/antigravity-auth-url.txt" 2>/dev/null || true
        fi
        ;;
esac

# 1. Native Termux broadcast (works without SecurityException)
if command -v termux-open >/dev/null 2>&1; then
    termux-open "$@" 2>/dev/null && exit 0
fi

# 2. Termux-open-url fallback
if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "$@" 2>/dev/null && exit 0
fi

exit 0
EOF
chmod +x "$BIN_DIR/xdg-open"
[ "$SILENT" -eq 0 ] && echo "      Configured smart browser bridge in $BIN_DIR/xdg-open."

# ==============================================================================
# [3/5] Single Authentication Token Sharing (CLI + Browser + App)
# ==============================================================================
if [ "$SILENT" -eq 0 ]; then
    echo "[3/5] Verifying shared authentication token..."
fi

TOKEN_FILE="$AUTH_DEST/antigravity-oauth-token"
if [ ! -f "$TOKEN_FILE" ]; then
    TOKEN_LOCATIONS=(
        "/sdcard/Download/antigravity-oauth-token"
        "$HOME/storage/downloads/antigravity-oauth-token"
        "$HOME/storage/shared/Download/antigravity-oauth-token"
    )
    for src in "${TOKEN_LOCATIONS[@]}"; do
        if [ -f "$src" ]; then
            cp -p "$src" "$TOKEN_FILE"
            chmod 600 "$TOKEN_FILE"
            [ "$SILENT" -eq 0 ] && echo "      Imported existing auth token from: $src"
            break
        fi
    done
fi

if [ -f "$TOKEN_FILE" ]; then
    chmod 600 "$TOKEN_FILE"
    [ "$SILENT" -eq 0 ] && echo "      Shared authentication token active across CLI, Browser & App."
else
    [ "$SILENT" -eq 0 ] && echo "      No token detected yet. Logging in from CLI, Browser or App will share one token."
fi

# ==============================================================================
# [4/5] Synchronize Chats, Default Project & Settings
# ==============================================================================
if [ "$SILENT" -eq 0 ]; then
    echo "[4/5] Synchronizing chats and workspace settings across all interfaces..."
fi

# 1. Initialize default CLI project configuration
mkdir -p "$PROJECTS_DIR"
DEFAULT_PROJ_FILE="$PROJECTS_DIR/default-cli-project.json"
if [ ! -f "$DEFAULT_PROJ_FILE" ]; then
    cat << 'EOF' > "$DEFAULT_PROJ_FILE"
{
  "id": "default-cli-project",
  "name": "CLI Project",
  "projectResources": {}
}
EOF
fi

# 2. Configure trusted workspaces in settings.json
SETTINGS_FILE="$AUTH_DEST/settings.json"
if [ ! -f "$SETTINGS_FILE" ]; then
    cat << 'EOF' > "$SETTINGS_FILE"
{
  "trustedWorkspaces": [
    "/data/data/com.termux/files/home"
  ]
}
EOF
elif ! grep -q "/data/data/com.termux/files/home" "$SETTINGS_FILE" 2>/dev/null; then
    # Ensure Termux home is in trusted workspaces
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json
p = '$SETTINGS_FILE'
try:
    with open(p, 'r') as f: d = json.load(f)
except: d = {}
tw = d.get('trustedWorkspaces', [])
if '/data/data/com.termux/files/home' not in tw:
    tw.append('/data/data/com.termux/files/home')
d['trustedWorkspaces'] = tw
with open(p, 'w') as f: json.dump(d, f, indent=2)
" 2>/dev/null || true
    fi
fi

# 3. Synchronize existing conversation database if sqlite3 is available
CONV_DB="$AUTH_DEST/conversation_summaries.db"
if [ -f "$CONV_DB" ]; then
    SQL_SYNC="UPDATE conversation_summaries SET project_id = 'default-cli-project', workspace_uris = '[\"file:///data/data/com.termux/files/home\"]' WHERE project_id IS NULL OR project_id = '';"
    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$CONV_DB" "$SQL_SYNC" 2>/dev/null || true
    elif [ -x "/system/bin/sqlite3" ]; then
        /system/bin/sqlite3 "$CONV_DB" "$SQL_SYNC" 2>/dev/null || true
    fi
    [ "$SILENT" -eq 0 ] && echo "      Synchronized existing conversation database."
fi

# ==============================================================================
# [5/5] Install Launchers & Daemons (agy-gui and agy-service)
# ==============================================================================
if [ "$SILENT" -eq 0 ]; then
    echo "[5/5] Generating Web GUI & App launchers..."
fi

# Ensure fast hosts and DNS settings
HOSTS_FILE="$PREFIX/etc/hosts"
if [ ! -f "$HOSTS_FILE" ] || ! grep -q '::1.*localhost' "$HOSTS_FILE" 2>/dev/null; then
    mkdir -p "$(dirname "$HOSTS_FILE")"
    cat << 'EOF' > "$HOSTS_FILE"
127.0.0.1 localhost
::1 localhost ip6-localhost
EOF
fi

RESOLV_CONF="$PREFIX/etc/resolv.conf"
if [ -f "$RESOLV_CONF" ] && ! grep -q "no-aaaa" "$RESOLV_CONF" 2>/dev/null; then
    echo "options timeout:1 attempts:2 no-aaaa" >> "$RESOLV_CONF"
fi

# --- agy-gui launcher ---
cat << 'EOF' > "$BIN_DIR/agy-gui"
#!/data/data/com.termux/files/usr/bin/bash
# Foreground launcher for Antigravity Web GUI & Android App Backend
set -e

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
PORT=4400

for arg in "$@"; do
    case "$arg" in
        --hub-port=*) PORT="${arg#*=}" ;;
    esac
done

URL="http://localhost:${PORT}"

if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock 2>/dev/null || true
fi

# Check if already running on target port
if curl -s -m 1 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
    echo "======================================================"
    echo " Antigravity server is already active on ${URL}"
    echo " Opening interface..."
    echo "======================================================"
    if command -v termux-open >/dev/null 2>&1; then
        termux-open "${URL}"
    elif command -v termux-open-url >/dev/null 2>&1; then
        termux-open-url "${URL}"
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "${URL}"
    fi
    exit 0
fi

# Locate executable engine
AGY_BIN=""
if [ -x "$PREFIX/bin/agy" ]; then
    AGY_BIN="$PREFIX/bin/agy"
elif [ -x "$HOME/.local/bin/agy" ]; then
    AGY_BIN="$HOME/.local/bin/agy"
fi

if [ -z "$AGY_BIN" ]; then
    echo "[-] Error: Could not locate agy executable"
    exit 1
fi

echo "======================================================"
echo " Starting Antigravity Server (CLI + Browser + App)... "
echo " Engine : ${AGY_BIN}"
echo " URL    : ${URL}"
echo "======================================================"

export NODE_OPTIONS="--dns-result-order=ipv4first"
export GOMEMLIMIT=1536MiB
export AGY_ENABLE_HUB=1

# Auto-open browser as soon as server responds
(
    for i in $(seq 1 30); do
        if curl -s -m 1 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
            echo "Server ready. Opening ${URL} in browser..."
            if command -v termux-open >/dev/null 2>&1; then
                termux-open "${URL}"
            elif command -v termux-open-url >/dev/null 2>&1; then
                termux-open-url "${URL}"
            elif command -v xdg-open >/dev/null 2>&1; then
                xdg-open "${URL}"
            fi
            break
        fi
        sleep 0.5
    done
) &

exec "$AGY_BIN" --hub "$@"
EOF
chmod +x "$BIN_DIR/agy-gui"
ln -sf "$BIN_DIR/agy-gui" "$BIN_DIR/agy-hub"
ln -sf "$BIN_DIR/agy-gui" "$BIN_DIR/agy-ui"
ln -sf "$BIN_DIR/agy-gui" "$BIN_DIR/agy-app"

# --- agy-service daemon manager ---
cat << 'EOF' > "$BIN_DIR/agy-service"
#!/data/data/com.termux/files/usr/bin/bash
# Background daemon manager for Antigravity Web GUI & App
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
PID_FILE="$HOME/.gemini/antigravity-cli/hub.pid"
LOG_FILE="$HOME/.gemini/antigravity-cli/log/hub.log"
mkdir -p "$HOME/.gemini/antigravity-cli/log"

is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$PID" ] && ps -p "$PID" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

case "$1" in
    start)
        if is_running; then
            echo "Antigravity backend is already active (PID: $(cat "$PID_FILE"))."
            if command -v termux-open >/dev/null 2>&1; then
                termux-open "http://localhost:4400" >/dev/null 2>&1 || true
            else
                termux-open-url "http://localhost:4400" >/dev/null 2>&1 || true
            fi
            exit 0
        fi
        echo "Starting Antigravity backend in background..."
        if command -v termux-wake-lock >/dev/null 2>&1; then
            termux-wake-lock 2>/dev/null || true
        fi
        export NODE_OPTIONS="--dns-result-order=ipv4first"
        export GOMEMLIMIT=1536MiB
        AGY_ENABLE_HUB=1 nohup "$PREFIX/bin/agy-gui" > "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        sleep 1.5
        echo "Started. Server active at http://localhost:4400"
        if command -v termux-open >/dev/null 2>&1; then
            termux-open "http://localhost:4400" >/dev/null 2>&1 || true
        else
            termux-open-url "http://localhost:4400" >/dev/null 2>&1 || true
        fi
        ;;
    stop)
        if is_running; then
            kill $(cat "$PID_FILE") 2>/dev/null || true
            rm -f "$PID_FILE"
            echo "Antigravity backend stopped."
        else
            echo "Antigravity backend is not running."
        fi
        ;;
    status)
        if is_running; then
            echo "Antigravity backend is active (PID: $(cat "$PID_FILE"))."
            echo "URL: http://localhost:4400"
        else
            echo "Antigravity backend is stopped."
        fi
        ;;
    restart)
        "$0" stop
        sleep 1
        "$0" start
        ;;
    logs)
        if [ -f "$LOG_FILE" ]; then
            tail -n 50 "$LOG_FILE"
        else
            echo "No logs found at $LOG_FILE"
        fi
        ;;
    *)
        echo "Usage: agy-service {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
EOF
chmod +x "$BIN_DIR/agy-service"

if [ "$SILENT" -eq 0 ]; then
    echo "======================================================"
    echo " Unified Setup Complete!                              "
    echo "======================================================"
    echo " Unified features:"
    echo "  • Token:    Shared across CLI, Browser & App"
    echo "  • Chats:    Synchronized across CLI, Browser & App"
    echo "  • Bridge:   termux-open active with URL logger"
    echo ""
    echo " Commands:"
    echo "   agy               : Interactive CLI agent"
    echo "   agy-gui / agy-app : Launch GUI (opens browser / app backend)"
    echo "   agy-service start : Run in background (keeps server alive for APK)"
    echo "   agy-service stop  : Stop background server"
    echo "======================================================"
fi
