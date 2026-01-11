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
