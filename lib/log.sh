# --------------------------------------------------
# Logging function
# --------------------------------------------------
log() {
    local msg="$1"
    if [ -n "$LOG_FILE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
    else
        echo "$msg"
    fi
}

# --------------------------------------------------
# Initialize / reset log
# --------------------------------------------------
reset_log() {
    # If no log file is configured, do nothing
    [ -z "$LOG_FILE" ] && return 0

    mkdir -p "$(dirname "$LOG_FILE")"
    : > "$LOG_FILE"
}
