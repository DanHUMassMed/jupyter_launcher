# --------------------------------------------------
# Fetch the latest GitHub tag from the repository
# --------------------------------------------------
get_latest_github_tag() {
    curl -fs "${GITHUB_API_URL}/tags" \
    | sed -n 's/.*"name":[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -n 1 || true
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
        log "🔄 Relaunching updated script..."
        open -a Terminal "$PWD/$RUN_FILE"
        exit 0
    else
        log "ℹ️  Update canceled by user"
    fi
}
