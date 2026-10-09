#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# Google Antigravity Web GUI Setup for Official Release (Android / Termux)
# ==============================================================================
# Configures the local Web GUI, browser launchers, service manager, and Termux
# environment for the official Google Antigravity CLI binary installed via:
#   curl -fsSL https://antigravity.google/cli/install.sh | bash
# ==============================================================================
set -e

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
BIN_DIR="${PREFIX}/bin"
USER_BIN="$HOME/.local/bin"

# Parse CLI arguments
SILENT=0
for arg in "$@"; do
    case "$arg" in
        --silent|-s|-q|--quiet) SILENT=1 ;;
    esac
done

if [ "$SILENT" -eq 0 ]; then
    echo "======================================================"
    echo "    Antigravity Web GUI Setup (Official Google CLI)   "
    echo "======================================================"
fi

# ==============================================================================
# [1/4] Locate Official Google Antigravity Binary & Fix Environment
# ==============================================================================
if [ "$SILENT" -eq 0 ]; then
    echo "[1/4] Verifying official Antigravity installation and environment..."
fi

mkdir -p "$BIN_DIR"
mkdir -p "$USER_BIN"

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
    echo "[-] Official Google Antigravity binary 'agy' is not installed."
    echo ""

    CHOICE=""
    if [ -t 0 ]; then
        read -r -p "Install official agy from Google? (curl -fsSL https://antigravity.google/cli/install.sh | bash) [y/n]: " CHOICE
    elif [ -e /dev/tty ]; then
        read -r -p "Install official agy from Google? (curl -fsSL https://antigravity.google/cli/install.sh | bash) [y/n]: " CHOICE < /dev/tty
    else
        CHOICE="n"
    fi

    case "$CHOICE" in
        [Yy]* )
            echo ""
            echo "Installing official Google Antigravity CLI..."
            TMP_BOOTSTRAP="$(mktemp 2>/dev/null || echo "$HOME/.local/bin/agy_install_tmp.sh")"
            if ! curl -fsSL --compressed https://antigravity.google/cli/install.sh -o "$TMP_BOOTSTRAP" 2>/dev/null; then
                curl -fsSL https://antigravity.google/cli/install.sh -o "$TMP_BOOTSTRAP"
            fi
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
            echo ""
            OFFICIAL_BIN="$(find_official_bin)"
            if [ -z "$OFFICIAL_BIN" ]; then
                echo "[-] Error: Installation completed but 'agy' binary could not be found."
                exit 1
            fi
            ;;
        * )
            echo ""
            echo "To install official Google Antigravity manually, run:"
            echo "  curl -fsSL --compressed https://antigravity.google/cli/install.sh | bash"
            echo ""
            echo "Exiting."
            exit 0
            ;;
    esac
fi

if [ "$SILENT" -eq 0 ]; then
    echo "      Found official binary at: $OFFICIAL_BIN"
fi

# Ensure agy is accessible globally in Termux system PATH ($BIN_DIR)
if [ "$OFFICIAL_BIN" != "$BIN_DIR/agy" ]; then
    ln -sf "$OFFICIAL_BIN" "$BIN_DIR/agy"
    [ "$SILENT" -eq 0 ] && echo "      Linked $OFFICIAL_BIN -> $BIN_DIR/agy"
fi

# Ensure ~/.local/bin and fast networking variables are present in ~/.bashrc
BASHRC="$HOME/.bashrc"
if [ ! -f "$BASHRC" ]; then
    touch "$BASHRC"
fi

if ! grep -q '\.local/bin' "$BASHRC" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
    [ "$SILENT" -eq 0 ] && echo "      Added ~/.local/bin to ~/.bashrc"
fi

# Clean up GODEBUG override if present (preserves Android Bionic netd for external Google APIs)
if grep -q 'GODEBUG.*netdns=go' "$BASHRC" 2>/dev/null; then
    sed -i '/GODEBUG.*netdns=go/d' "$BASHRC" 2>/dev/null || true
fi
unset GODEBUG 2>/dev/null || true

# Force Node.js (used by LSP / language tools) to prioritize IPv4
if ! grep -q 'NODE_OPTIONS.*ipv4first' "$BASHRC" 2>/dev/null; then
    echo 'export NODE_OPTIONS="--dns-result-order=ipv4first"' >> "$BASHRC"
    [ "$SILENT" -eq 0 ] && echo "      Added NODE_OPTIONS=\"--dns-result-order=ipv4first\" to ~/.bashrc"
fi

# Optimize Go memory limit on mobile devices to prevent GC thrashing and OOM kills
if ! grep -q 'GOMEMLIMIT' "$BASHRC" 2>/dev/null; then
    echo 'export GOMEMLIMIT=1536MiB' >> "$BASHRC"
    [ "$SILENT" -eq 0 ] && echo "      Added GOMEMLIMIT=1536MiB to ~/.bashrc"
fi

# Setup xdg-open bridge to termux-open-url so agy can open browser tabs for OAuth
if command -v termux-open-url >/dev/null 2>&1; then
    ln -sf "$BIN_DIR/termux-open-url" "$BIN_DIR/xdg-open" 2>/dev/null || true
    [ "$SILENT" -eq 0 ] && echo "      Configured browser bridge (xdg-open -> termux-open-url) for OAuth."
elif command -v termux-open >/dev/null 2>&1; then
    ln -sf "$BIN_DIR/termux-open" "$BIN_DIR/xdg-open" 2>/dev/null || true
    [ "$SILENT" -eq 0 ] && echo "      Configured browser bridge (xdg-open -> termux-open) for OAuth."
fi

# ==============================================================================
# [2/4] Network & Fast DNS Optimization
# ==============================================================================
if [ "$SILENT" -eq 0 ]; then
    echo "[2/4] Optimizing DNS & hosts settings to prevent network delays..."
fi

# Fix Termux hosts mapping for dual-stack localhost resolution
HOSTS_FILE="$PREFIX/etc/hosts"
mkdir -p "$(dirname "$HOSTS_FILE")"
if [ ! -f "$HOSTS_FILE" ] || ! grep -q '::1.*localhost' "$HOSTS_FILE" 2>/dev/null; then
    cat << 'EOF' > "$HOSTS_FILE"
127.0.0.1 localhost
::1 localhost ip6-localhost
EOF
    [ "$SILENT" -eq 0 ] && echo "      Configured $HOSTS_FILE with fast localhost bindings."
else
    [ "$SILENT" -eq 0 ] && echo "      Hosts file already configured."
fi

RESOLV_CONF="$PREFIX/etc/resolv.conf"
if [ -f "$RESOLV_CONF" ]; then
    if ! grep -q "no-aaaa" "$RESOLV_CONF" 2>/dev/null; then
        echo "options timeout:1 attempts:2 no-aaaa" >> "$RESOLV_CONF"
        [ "$SILENT" -eq 0 ] && echo "      Applied fast DNS resolver configuration."
    else
        [ "$SILENT" -eq 0 ] && echo "      DNS resolver already optimized."
    fi
else
    mkdir -p "$(dirname "$RESOLV_CONF")"
    echo "nameserver 8.8.8.8" > "$RESOLV_CONF"
    echo "nameserver 1.1.1.1" >> "$RESOLV_CONF"
    echo "options timeout:1 attempts:2 no-aaaa" >> "$RESOLV_CONF"
    [ "$SILENT" -eq 0 ] && echo "      Created resolv.conf with fast DNS settings."
fi

# ==============================================================================
# [3/4] Privacy-First Authentication Storage Verification
# ==============================================================================
if [ "$SILENT" -eq 0 ]; then
    echo "[3/4] Verifying private authentication storage..."
fi

AUTH_DEST="$HOME/.gemini/antigravity-cli"
mkdir -p "$AUTH_DEST"
chmod 700 "$AUTH_DEST"

TOKEN_FILE="$AUTH_DEST/antigravity-oauth-token"
if [ -f "$TOKEN_FILE" ]; then
    chmod 600 "$TOKEN_FILE"
    [ "$SILENT" -eq 0 ] && echo "      Existing authentication token verified in ~/.gemini/antigravity-cli."
else
    [ "$SILENT" -eq 0 ] && echo "      No local token detected. You can log in via browser on first launch."
fi

# ==============================================================================
# [4/4] Create Web GUI Launchers (agy-gui and agy-service)
# ==============================================================================
if [ "$SILENT" -eq 0 ]; then
    echo "[4/4] Generating Web GUI launchers in $BIN_DIR..."
fi

# --- agy-gui foreground launcher ---
cat << 'EOF' > "$BIN_DIR/agy-gui"
#!/data/data/com.termux/files/usr/bin/bash
# Foreground launcher for Official Google Antigravity Web GUI
set -e

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
PORT=4400

# Parse custom port if provided
for arg in "$@"; do
    case "$arg" in
        --hub-port=*) PORT="${arg#*=}" ;;
    esac
done

URL="http://localhost:${PORT}"

# Acquire Termux wake lock to prevent Android from killing/suspending the language server
if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock 2>/dev/null || true
fi

# Ensure fast hosts and DNS settings
HOSTS_FILE="$PREFIX/etc/hosts"
if [ ! -f "$HOSTS_FILE" ] || ! grep -q '::1.*localhost' "$HOSTS_FILE" 2>/dev/null; then
    mkdir -p "$(dirname "$HOSTS_FILE")"
    cat << 'HEOF' > "$HOSTS_FILE"
127.0.0.1 localhost
::1 localhost ip6-localhost
HEOF
fi

RESOLV_CONF="$PREFIX/etc/resolv.conf"
if [ -f "$RESOLV_CONF" ] && ! grep -q "no-aaaa" "$RESOLV_CONF" 2>/dev/null; then
    echo "options timeout:1 attempts:2 no-aaaa" >> "$RESOLV_CONF"
fi

# Check if already running on target port
if curl -s -m 1 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
    echo "======================================================"
    echo " Antigravity GUI is already running on ${URL}"
    echo " Opening browser..."
    echo "======================================================"
    if command -v termux-open-url >/dev/null 2>&1; then
        termux-open-url "${URL}"
    elif command -v termux-open >/dev/null 2>&1; then
        termux-open "${URL}"
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
    echo "[-] Error: Could not locate agy executable in $PREFIX/bin or $HOME/.local/bin"
    exit 1
fi

echo "======================================================"
echo " Starting Antigravity Local Web GUI..."
echo " Engine : ${AGY_BIN}"
echo " URL    : ${URL}"
echo "======================================================"

# Prioritize IPv4 for Node tools while keeping Bionic netd for Go
export NODE_OPTIONS="--dns-result-order=ipv4first"
export GOMEMLIMIT=1536MiB
export AGY_ENABLE_HUB=1

# Auto-open browser as soon as server responds
(
    for i in $(seq 1 30); do
        if curl -s -m 1 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
            echo "Server ready. Opening ${URL} in browser..."
            if command -v termux-open-url >/dev/null 2>&1; then
                termux-open-url "${URL}"
            elif command -v termux-open >/dev/null 2>&1; then
                termux-open "${URL}"
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

# Friendly symlinks
ln -sf "$BIN_DIR/agy-gui" "$BIN_DIR/agy-hub"
ln -sf "$BIN_DIR/agy-gui" "$BIN_DIR/agy-ui"

# --- agy-service daemon manager ---
cat << 'EOF' > "$BIN_DIR/agy-service"
#!/data/data/com.termux/files/usr/bin/bash
# Background daemon manager for Antigravity Web GUI
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
            echo "Antigravity Web GUI is already running (PID: $(cat "$PID_FILE"))."
            termux-open-url "http://localhost:4400" >/dev/null 2>&1 || true
            exit 0
        fi
        echo "Starting Antigravity Web GUI in background..."
        if command -v termux-wake-lock >/dev/null 2>&1; then
            termux-wake-lock 2>/dev/null || true
        fi
        export NODE_OPTIONS="--dns-result-order=ipv4first"
        export GOMEMLIMIT=1536MiB
        AGY_ENABLE_HUB=1 nohup "$PREFIX/bin/agy-gui" > "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        sleep 1.5
        echo "Started. URL: http://localhost:4400"
        termux-open-url "http://localhost:4400" >/dev/null 2>&1 || true
        ;;
    stop)
        if is_running; then
            kill $(cat "$PID_FILE") 2>/dev/null || true
            rm -f "$PID_FILE"
            echo "Antigravity Web GUI stopped."
        else
            echo "Antigravity Web GUI is not running."
        fi
        ;;
    status)
        if is_running; then
            echo "Antigravity Web GUI is running (PID: $(cat "$PID_FILE"))."
            echo "URL: http://localhost:4400"
        else
            echo "Antigravity Web GUI is stopped."
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

# Self-copy so user can run 'agy-patch-official' directly
cp -f "$0" "$BIN_DIR/agy-patch-official" 2>/dev/null || true
chmod +x "$BIN_DIR/agy-patch-official" 2>/dev/null || true

if [ "$SILENT" -eq 0 ]; then
    echo "======================================================"
    echo " Antigravity Web GUI Setup Complete!                  "
    echo "======================================================"
    echo " Commands available:"
    echo "   agy               : Interactive CLI agent"
    echo "   agy-gui           : Open Web GUI in browser (foreground)"
    echo "   agy-service start : Run Web GUI in background"
    echo "   agy-service status: Check background service status"
    echo "   agy-service stop  : Stop background service"
    echo "======================================================"
fi
