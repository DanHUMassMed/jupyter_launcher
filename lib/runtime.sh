# --------------------------------------------------
# Enforce single running instance
# --------------------------------------------------
enforce_single_instance() {
    log "🔍 Checking for previous Jupyter instance..."
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            CMD=$(ps -p "$OLD_PID" -o args=)
            if echo "$CMD" | grep -qi jupyter; then
                log "🛑 Stopping previous Jupyter (PID $OLD_PID)..."
                kill "$OLD_PID" 2>/dev/null || true

                # Wait up to 5 seconds for process to die
                for i in {1..10}; do
                    if ! ps -p "$OLD_PID" >/dev/null 2>&1; then
                        break
                    fi
                    sleep 0.5
                done

                # Force kill if still alive
                if ps -p "$OLD_PID" >/dev/null 2>&1; then
                    log "⚠️ Process still running, killing forcefully..."
                    kill -9 "$OLD_PID" 2>/dev/null || true
                fi
            fi
        fi
        rm -f "$PID_FILE"
    fi
}


# -------------------------------------------------------------------
# Runtime copy for local notebooks
# -------------------------------------------------------------------
# By default, make local runtime copies to ~/notebooks/<project>

create_local_runtime() {
    # Project name is the last directory name where the script lives
    # Global SCRIPT_DIR should be set by orchestrator
    PROJECT_NAME=$(basename "$SCRIPT_DIR")
    TARGET_DIR="$TARGET_BASE/$PROJECT_NAME"

    # If the script is already running inside ~/notebooks/<project>, do nothing
    if [ "$SCRIPT_DIR" = "$TARGET_DIR" ] || [ "$WANT_LOCAL_RUNTIME" != "1" ]; then
        log "ℹ️  Local runtime disabled or already running inside $TARGET_DIR — no copy."
        return 0
    fi

    log "📁 Creating local runtime directory: $TARGET_DIR"

    # Create target directory
    mkdir -p "$TARGET_DIR" || {
        log "❌ Failed to create target runtime directory: $TARGET_DIR"
        return 1
    }

    # Copy project structure
    # - launch_jupyter.command wrapper
    # - brew.txt, requirements.txt
    # - data directory
    # - *.ipynb
    echo "{\"SOURCE_DIR\":\"$SCRIPT_DIR\"}" > "$TARGET_DIR/source_dir.json"
    cp -p "launch_jupyter.command" "$TARGET_DIR/" 2>/dev/null || true

    [ -f "brew.txt" ] && cp -p "brew.txt" "$TARGET_DIR/" || true
    [ -f "requirements.txt" ] && cp -p "requirements.txt" "$TARGET_DIR/" || true
    
    if [[ -d "data" ]]; then
        log "📁 data copied to $TARGET_DIR/"
        DIR_SIZE_MB=$(du -sm "data" | cut -f1)
        if (( DIR_SIZE_MB > THRESHOLD_MB )); then
            osascript <<EOF
display notification "Copying 'data' directory of ${DIR_SIZE_MB}MB ..." with title "Directory Size Warning"  
EOF
        fi
        cp -Rp "data" "$TARGET_DIR/"
    fi

    # Copy notebooks, ignoring *_warning*.ipynb
    shopt -s nullglob
    for nb in *.ipynb; do
        case "$nb" in
            *_warning*.ipynb) 
                # skip warning notebooks
                continue
                ;;
            .ipynb_checkpoints/*)
                # skip checkpoint folder matches (defensive)
                continue
                ;;
            *)
                cp -p "$nb" "$TARGET_DIR/" || true
                ;;
        esac
    done
    shopt -u nullglob


    # Make the copy atomic-ish for notebooks: if large repos or files change, we don't want partial copies.
    # We already used cp for simplicity; a more robust alternative is rsync --partial etc.
    log "✅ Copied project structure to $TARGET_DIR"

    [ -f "log.txt" ] && cp -p "log.txt" "$TARGET_DIR/" || true
    
    # Now switch script working dir to the runtime directory so the rest of the script operates there
    cd "$TARGET_DIR" || {
        log "❌ Failed to cd into $TARGET_DIR"
        exit 1
    }
    log "🔁 Switching to runtime directory."

    # Update SCRIPT_DIR to the new runtime location so the rest of the script uses it
    SCRIPT_DIR="$(pwd)"
    log "📂 Now operating in $SCRIPT_DIR"
}
