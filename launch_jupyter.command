#!/bin/bash
set -e

# ==================================================
# Configuration
# ==================================================

CURRENT_VERSION=v0.1.4 # VERSION_LINE Bumped when a new release is made
DEFAULT_PY_VERSION="3.13"
LOG_FILE="log.txt"

REPO_OWNER="DanHUMassMed"
REPO_NAME="jupyter_launcher"
REPO_PATH="${REPO_OWNER}/${REPO_NAME}"

GITHUB_API_URL="https://api.github.com/repos/${REPO_PATH}"
RAW_BASE_URL="https://raw.githubusercontent.com/${REPO_PATH}"

BRANCH="main"
RUN_FILE="launch_jupyter.command"

# Enable local runtime copy by default
WANT_LOCAL_RUNTIME=${WANT_LOCAL_RUNTIME:-1}
THRESHOLD_MB=10

# Initialize Script Directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_BASE="$HOME/notebooks"

# Define PID file location (global)
PID_FILE="$HOME/.jupyter-app.pid"

# ==================================================

# ==================================================
# EMBEDDED LIBRARIES
# ==================================================

# *** START log.sh ***
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

# *** END log.sh ***

# *** START os.sh ***
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

# *** END os.sh ***

# *** START github.sh ***
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

# *** END github.sh ***

# *** START python.sh ***
# --------------------------------------------------
# Ensure 'uv' is installed
# --------------------------------------------------
install_uv() {
    if ! command -v uv >/dev/null 2>&1; then
        log "📦 Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi
}

# --------------------------------------------------
# Determine Python version
# --------------------------------------------------
determine_python_version() {
    if [ -f "version.txt" ]; then
        PY_VERSION=$(grep '^python=' version.txt | cut -d= -f2)
    fi
    PY_VERSION="${PY_VERSION:-$DEFAULT_PY_VERSION}"
    log "🐍 Using Python $PY_VERSION"
}

# --------------------------------------------------
# Ensure Python exists (idempotent)
# --------------------------------------------------
ensure_python() {
    uv python install "$PY_VERSION"
}

# --------------------------------------------------
# Initialize uv project
# --------------------------------------------------
init_uv_project() {
    if [ ! -f "pyproject.toml" ]; then
        log "📄 Initializing uv project..."
        uv init --bare

        if [ -f "requirements.txt" ]; then
            log "📥 Importing requirements.txt..."
            uv add $(cat requirements.txt)
        fi
    fi
}

# --------------------------------------------------
# Create virtual environment
# --------------------------------------------------
create_venv() {
    if [ ! -d ".venv" ]; then
        log "🔧 Creating virtual environment..."
        uv venv --python "$PY_VERSION"
    fi
}

# --------------------------------------------------
# Sync dependencies
# --------------------------------------------------
sync_dependencies() {
    log "🔄 Syncing dependencies..."
    uv sync
}

# --------------------------------------------------
# Ensure ipykernel is installed
# --------------------------------------------------
ensure_ipykernel() {
    log "📄 Ensuring ipykernel and nbformat are installed..."
    uv add ipykernel
    uv add jupyterlab
    uv add nbformat
    uv sync
    log "📄 Added ipykernel and nbformat"
}

# *** END python.sh ***

# *** START runtime.sh ***
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

    # Backup if it already exists
    backup_dir_if_exists "$TARGET_DIR" || return 1

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



# *** END runtime.sh ***

# *** START brew.sh ***
# --------------------------------------------------
# Check Brew dependencies, generate warning notebook if needed
# --------------------------------------------------
check_brew_dependencies() {
    WARNINGS=()
    MISSING_PKGS=()
    WARNING_FILE="warning.md"

    # Check brew packages
    if [ -f "brew.txt" ]; then
        log "Checking for any missing Brew dependencies..."
        if ! command -v brew >/dev/null 2>&1; then
            WARNINGS+=("Homebrew is not installed.")
        else
            while read -r pkg; do
                [ -z "$pkg" ] && continue
                if ! brew list "$pkg" >/dev/null 2>&1; then
                    MISSING_PKGS+=("$pkg")
                fi
            done < brew.txt

            if [ "${#MISSING_PKGS[@]}" -ne 0 ]; then
                WARNINGS+=("Missing Homebrew packages: ${MISSING_PKGS[*]}")
            fi
        fi
    fi
    log "Testing if any warnings are present... ${#WARNINGS[@]}"
    # Only generate warning if needed
    if [ "${#WARNINGS[@]}" -ne 0 ]; then
        # Create Markdown warning
        {
            echo "# ⚠️ System Dependency Warning"
            echo
            echo "This notebook may not run correctly because some system dependencies are missing."
            echo
            echo "## Details"

            if ! command -v brew >/dev/null 2>&1; then
                echo "### Homebrew not installed"
                echo "Install Homebrew from: https://brew.sh"
                echo
            fi

            if [ "${#MISSING_PKGS[@]}" -ne 0 ]; then
                echo "### Missing Homebrew packages"
                for pkg in "${MISSING_PKGS[@]}"; do
                    echo "- $pkg"
                done
                echo
                echo "Install them with:"
                echo '```bash'
                echo "brew install ${MISSING_PKGS[*]}"
                echo '```'
            fi

            echo
            echo "> This warning does not prevent the notebook from opening."
            echo "> Re-run \`launch_jupyter.command\` after installing dependencies."
        } > "$WARNING_FILE"

        # Copy notebook to *_warning.ipynb
        NOTEBOOK_WARNING="${NOTEBOOK%.ipynb}_warning.ipynb"
        cp "$NOTEBOOK" "$NOTEBOOK_WARNING"
        log "📓 Created warning notebook: $NOTEBOOK_WARNING"

        # 🔑 IMPORTANT: point NOTEBOOK to the warning version
        NOTEBOOK="$NOTEBOOK_WARNING"

        # Call python script
        INJECT_WARNING_FILE="inject_warning.py"
        write_inject_warning_script "$INJECT_WARNING_FILE"
        uv run python "$INJECT_WARNING_FILE" "$NOTEBOOK" "$WARNING_FILE"
        rm -f "$INJECT_WARNING_FILE"

    else
        # Remove warning file if no warnings exist
        if [ -n "$WARNING_FILE" ] && [ -f "$WARNING_FILE" ]; then
            log "Removing warning file..."
            rm -f "$WARNING_FILE"
        fi
    fi
}

# --------------------------------------------------
# PYTHON SCRIPTS
# --------------------------------------------------

write_inject_warning_script() {
  local target="$1"
  cat > "$target" <<'PYCODE'
import sys
import nbformat
from pathlib import Path

if len(sys.argv) < 3:
    print("Usage: python inject_warning.py <notebook_file> <warning_file>")
    sys.exit(1)

notebook_file = sys.argv[1]
warning_file = sys.argv[2]
MARKER = "<!-- SYSTEM DEPENDENCY WARNING -->"

# Read notebook
nb = nbformat.read(notebook_file, as_version=4)

# Check if warning cell already exists
for cell in nb.cells:
    if cell.cell_type == "markdown" and MARKER in cell.source:
        break
else:
    # Read warning content
    warning_text = Path(warning_file).read_text()
    warning_text = f"{MARKER}\n\n{warning_text}"

    # Insert as first cell
    warning_cell = nbformat.v4.new_markdown_cell(warning_text)
    nb.cells.insert(0, warning_cell)

    # Save notebook
    nbformat.write(nb, notebook_file)
PYCODE
}
# *** END brew.sh ***

# *** START notebook.sh ***
# --------------------------------------------------
# Find first notebook (ignore *_warning.ipynb)
# Create one if none exists
# --------------------------------------------------
find_notebook() {
    NOTEBOOK=$(ls *.ipynb 2>/dev/null | grep -v '_warning.ipynb' | head -n 1)

    if [ -z "$NOTEBOOK" ]; then
        PROJECT_NAME="$(basename "$PWD")"
        NOTEBOOK="${PROJECT_NAME}.ipynb"

        log "📓 No notebook found — creating ${NOTEBOOK}..."

        CREATE_NOTEBOOK_FILE="create_notebook.py"
        write_create_notebook_script "$CREATE_NOTEBOOK_FILE"
        uv run python "$CREATE_NOTEBOOK_FILE" "$PROJECT_NAME" "$NOTEBOOK"
        rm -f "$CREATE_NOTEBOOK_FILE"

        log "✅ Created ${NOTEBOOK}"
    else
        log "📓 First notebook found: $NOTEBOOK"
    fi
}

# --------------------------------------------------
# Register unique kernel
# --------------------------------------------------
register_kernel() {
    KERNEL_NAME="project-$(basename "$PWD")"
    KERNEL_DISPLAY="Python (.venv $(basename "$PWD"))"

    log "📄 Registering kernel: $KERNEL_NAME"

    # If kernel exists, delete it first (stale paths are common)
    if uv run jupyter kernelspec list | grep -q "^$KERNEL_NAME[[:space:]]"; then
        log "♻️ Removing existing kernel: $KERNEL_NAME"
        jupyter kernelspec remove -f "$KERNEL_NAME"
        sleep 1
    fi

    # Recreate kernel pointing to current .venv
    uv run python -m ipykernel install \
        --user \
        --name "$KERNEL_NAME" \
        --display-name "$KERNEL_DISPLAY"

    log "✅ Kernel registered: $KERNEL_DISPLAY"
}


# --------------------------------------------------
# Update notebook metadata
# --------------------------------------------------
update_notebook_metadata() {
    UPDATE_METADATA_FILE="update_metadata.py"
    write_update_metadata_script "$UPDATE_METADATA_FILE"
    uv run python "$UPDATE_METADATA_FILE" "$NOTEBOOK" "$KERNEL_NAME" "$KERNEL_DISPLAY"
    rm -f "$UPDATE_METADATA_FILE"   
}

# --------------------------------------------------
# Launch Jupyter Lab
# --------------------------------------------------
launch_jupyter() {
    export JUPYTER_DISABLE_CONFIG=1

    log "🌐 Launching Jupyter Lab..."

    PORT=$(pick_free_port)
    JUPYTER_LOG="$TARGET_DIR/jupyter.log"

    nohup uv run jupyter lab "$NOTEBOOK" \
        --ServerApp.open_browser=False \
        --ServerApp.allow_remote_access=True \
        --ServerApp.root_dir="$TARGET_DIR" \
        --ServerApp.port="$PORT" \
        > "$JUPYTER_LOG" 2>&1 &

    NEW_PID=$!
    echo "$NEW_PID" > "$PID_FILE"

    # Wait for server
    for i in {1..20}; do
        grep -q "http://127.0.0.1:$PORT" "$JUPYTER_LOG" && break
        sleep 0.3
    done

    JUPYTER_URL=$(grep -oE "http://127\.0\.0\.1:$PORT/lab\?token=[a-z0-9]+" "$JUPYTER_LOG" | head -n 1)

    if [ -n "$JUPYTER_URL" ]; then
        log "🔗 Notebook URL: $JUPYTER_URL"
        echo "$JUPYTER_URL" > "$TARGET_DIR/jupyter_url.txt"
    else
        log "⚠️ Failed to detect Jupyter URL (check $JUPYTER_LOG)"
    fi
}

# --------------------------------------------------
# Open Jupyter Lab in browser (macOS only)
# --------------------------------------------------
open_jupyter() {
    URL_FILE="$TARGET_DIR/jupyter_url.txt"

    if [ -f "$URL_FILE" ]; then
        JUPYTER_URL=$(<"$URL_FILE")
        if [ -n "$JUPYTER_URL" ]; then
            log "🌐 Opening Jupyter Lab at $JUPYTER_URL"
            open "$JUPYTER_URL"
            return 0
        fi
    fi

    # If we reach here, something went wrong
    log "❌ Jupyter URL not found. Did the server start correctly?"
    osascript -e 'display notification "Failed to detect Jupyter URL. Check logs." with title "Jupyter Launcher"'
}

# --------------------------------------------------
# PYTHON SCRIPTS
# --------------------------------------------------

write_create_notebook_script() {
  local target="$1"
  cat > "$target" <<'PYCODE'
import sys
import nbformat

if len(sys.argv) < 3:
    print("Usage: python create_notebook.py <project_name> <notebook_filename>")
    sys.exit(1)

project_name = sys.argv[1]
notebook_filename = sys.argv[2]

nb = nbformat.v4.new_notebook(
    cells=[
        nbformat.v4.new_markdown_cell(
            f"# {project_name}\n\n"
            "This notebook was auto-generated by **launch_jupyter.command**.\n"
            "You can safely rename or delete it."
        )
    ],
    metadata={
        "kernelspec": {
            "name": "python3",
            "display_name": "Python 3",
            "language": "python"
        }
    }
)

with open(notebook_filename, "w", encoding="utf-8") as f:
    nbformat.write(nb, f)
print(f"Created {notebook_filename}")
PYCODE
}

write_update_metadata_script() {
  local target="$1"
  cat > "$target" <<'PYCODE'
import sys
import json

if len(sys.argv) < 4:
    print("Usage: python update_metadata.py <notebook_file> <kernel_name> <kernel_display>")
    sys.exit(1)

nb_file = sys.argv[1]
kernel_name = sys.argv[2]
kernel_display = sys.argv[3]

with open(nb_file, "r", encoding="utf-8") as f:
    nb = json.load(f)

nb['metadata']['kernelspec'] = {
    "name": kernel_name,
    "display_name": kernel_display,
    "language": "python"
}

with open(nb_file, "w", encoding="utf-8") as f:
    json.dump(nb, f, indent=2)

PYCODE
}

# *** END notebook.sh ***

# ==================================================
# Main Execution Flow
# ==================================================
main() {
    cd "$SCRIPT_DIR" || {
        log "❌ Failed to cd into $SCRIPT_DIR"
        exit 1
    }

    reset_log
    log "=================================================="
    log "🚀 Starting Jupyter Notebook App"
    log "📁 Directory: $SCRIPT_DIR"
    log "--------------------------------------------------"

    require_mac_os
    #read -p "Press Enter to continue...1" _ </dev/tty
    check_for_updates
    create_local_runtime
    
    # Note: create_local_runtime may switch PWD and update SCRIPT_DIR
    
    install_uv
    determine_python_version
    ensure_python
    init_uv_project
    create_venv
    sync_dependencies
    ensure_ipykernel
    
    find_notebook
    enforce_single_instance
    check_brew_dependencies
    register_kernel
    update_notebook_metadata
    
    launch_jupyter
    open_jupyter
    
    log "=================================================="
}

main "$@"
