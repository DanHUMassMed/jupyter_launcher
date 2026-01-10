#!/bin/bash
set -euo pipefail

# --------------------------------------------------
# Logging function
# Logs messages to console or a log file if LOG_FILE is set
# --------------------------------------------------
log() {
    local msg="$1"
    if [ -n "${LOG_FILE:-}" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
    else
        echo "$msg"
    fi
}

LOG_FILE="log.txt"  # optional: if set, logs are written here

# --------------------------------------------------
# Configuration
# --------------------------------------------------
CURRENT_VERSION="v0.1.0"

REPO_OWNER="DanHUMassMed"
REPO_NAME="jupyter_launcher"
REPO_PATH="${REPO_OWNER}/${REPO_NAME}"

GITHUB_API_URL="https://api.github.com/repos/${REPO_PATH}"
RAW_BASE_URL="https://raw.githubusercontent.com/${REPO_PATH}"

BRANCH="main"
RUN_FILE="launch_jupyter.command"

# --------------------------------------------------
# Functions
# --------------------------------------------------

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
# Fetch the latest GitHub tag from the repository
# --------------------------------------------------
get_latest_github_tag() {
    curl -fs "${GITHUB_API_URL}/tags" \
    | sed -n 's/.*"name":[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -n 1 || true
}

# --------------------------------------------------
# Show a macOS dialog asking user whether to install update
# Returns button clicked
# --------------------------------------------------
mac_confirm_update() {
    osascript <<EOF
display dialog "Update Available. Install?" buttons {"Cancel", "Install"} default button "Install"
EOF
}

# --------------------------------------------------
# Download the latest version of the script from GitHub
# Overwrites the existing file and makes it executable
# --------------------------------------------------
download_run_command() {
    local url="${RAW_BASE_URL}/refs/heads/${BRANCH}/${RUN_FILE}"
    local tmp="${RUN_FILE}.tmp"

    log "📥 Downloading ${RUN_FILE} from ${REPO_PATH} (${BRANCH})"

    curl -fsSL "${url}" -o "${tmp}"
    mv "${tmp}" "${RUN_FILE}"
    chmod +x "${RUN_FILE}"

    log "✅ ${RUN_FILE} updated"
}

# --------------------------------------------------
# Check for updates:
# 1. Skip if curl is missing
# 2. Skip if latest version matches current
# 3. Skip if no write permission
# 4. Prompt user to install if new version is available
# --------------------------------------------------
check_for_updates() {
    # Check if curl exists
    if ! require_curl; then
        return 0
    fi

    log "🔍 Checking for updates..."
    log "Current version: ${CURRENT_VERSION}"

    local latest_tag
    latest_tag=$(get_latest_github_tag)

    if [[ -z "${latest_tag}" ]]; then
        log "⚠️  No GitHub tags found — skipping update"
        return 0
    fi

    if [[ "${latest_tag}" == "${CURRENT_VERSION}" ]]; then
        log "✅ Already up to date"
        return 0
    fi

    log "⬆️  New version detected: ${latest_tag}"

    # Check write permission
    if [[ ! -w "$(pwd)" ]]; then
        log "⚠️  No write permission in current directory — cannot update"
        return 0
    fi

    # Prompt user
    if mac_confirm_update; then
        download_run_command
    else
        log "ℹ️  Update canceled by user"
    fi
}

# --------------------------------------------------
# Entry point
# --------------------------------------------------
check_for_updates
