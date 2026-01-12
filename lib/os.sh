# --------------------------------------------------
# Check if curl is installed; returns 1 if missing
# --------------------------------------------------
require_curl() {
    if ! command -v curl >/dev/null 2>&1; then
        log "⚠️ curl is not installed — skipping update"
        return 1
    fi
    return 0
}

# --------------------------------------------------
# Show a macOS dialog asking user whether to install update
# Returns button clicked
# --------------------------------------------------
mac_confirm_update() {
    osascript <<EOF
display dialog "Launch Jupyter App Update Available. Install?" buttons {"Later", "Install"} default button "Install"
EOF
}

# --------------------------------------------------
# Check if running on macOS; exit if not
# --------------------------------------------------
require_mac_os() {
    if [[ "$(uname)" != "Darwin" ]]; then
        echo "❌ This script only runs on macOS. Exiting."
        return 1
    fi
    return 0
}

pick_free_port() {
    for port in $(seq 8000 9000); do
        # try to connect to see if port is in use
        (echo >/dev/tcp/127.0.0.1/$port) >/dev/null 2>&1 || {
            echo "$port"
            return 0
        }
    done
    echo "No free ports in range 8000–9000" >&2
    return 1
}

# --------------------------------------------------
# Find next available versioned backup name
# e.g. mydir -> mydir_v1, mydir_v2, ...
# --------------------------------------------------
next_backup_name() {
    local base="$1"
    local n=1
    local candidate

    while :; do
        candidate="${base}_v${n}"
        if [ ! -e "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
        n=$((n + 1))
    done
}

# --------------------------------------------------
# Backup directory if it exists
# --------------------------------------------------
backup_dir_if_exists() {
    local dir="$1"

    if [ ! -d "$dir" ]; then
        return 0
    fi

    local backup
    backup="$(next_backup_name "$dir")"

    log "📦 Backing up existing directory:"
    log "   $dir  →  $backup"

    mv "$dir" "$backup" || {
        log "❌ Failed to move $dir to $backup"
        return 1
    }
}
