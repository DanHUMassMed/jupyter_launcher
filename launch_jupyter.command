#!/bin/bash
set -e

CURRENT_VERSION=v0.1.4 # VERSION_LINE Bumped when a new release is made

# --------------------------------------------------
# Finder-safe: always run from script directory
# --------------------------------------------------
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"
PID_FILE="$HOME/.jupyter-app.pid"
WARNING_FILE="WARNING.md"
DEFAULT_PY_VERSION="3.13"
LOG_FILE="log.txt"  # optional: if set, logs are written here

REPO_OWNER="DanHUMassMed"
REPO_NAME="jupyter_launcher"
REPO_PATH="${REPO_OWNER}/${REPO_NAME}"

GITHUB_API_URL="https://api.github.com/repos/${REPO_PATH}"
RAW_BASE_URL="https://raw.githubusercontent.com/${REPO_PATH}"

BRANCH="main"
RUN_FILE="launch_jupyter.command"

# Set WANT_LOCAL_RUNTIME=1 at top of script to enable.
WANT_LOCAL_RUNTIME=${WANT_LOCAL_RUNTIME:-1}
THRESHOLD_MB=10


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
display dialog "Launch Jupyter App Update Available. Install?" buttons {"Cancel", "Install"} default button "Install"
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
        log "🔄 Relaunching updated script..."
        open -a Terminal "$PWD/$RUN_FILE"
        exit 0
    else
        log "ℹ️  Update canceled by user"
    fi
}

# -------------------------------------------------------------------
# Runtime copy for local notebooks
# -------------------------------------------------------------------
# By default, make local runtime copies to ~/notebooks/<project>

create_local_runtime() {
    # The name of this script (we already cd'd to script dir earlier)
    SCRIPT_NAME=$(basename "$0")

    # Project name is the last directory name where launch_jupyter.command lives
    PROJECT_NAME=$(basename "$SCRIPT_DIR")
    TARGET_BASE="$HOME/notebooks"
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

    # Copy selected files (preserve mode/timestamps when possible)
    # - launch_jupyter.command (this script)
    # - brew.txt
    # - requirements.txt
    # - *.ipynb (ignore *_warning*.ipynb)
    #
    # Use safe checks so we don't fail when files don't exist.
    cp -p "$SCRIPT_NAME" "$TARGET_DIR/" 2>/dev/null || true
    cp -p "$RUN_FILE" "$TARGET_DIR/" 2>/dev/null || true
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
    log "✅ Copied launch_jupyter.command, brew.txt, requirements.txt and notebooks to $TARGET_DIR"

    [ -f "log.txt" ] && cp -p "log.txt" "$TARGET_DIR/" || true
    log "🔁 Switching to runtime directory."

    # Now switch script working dir to the runtime directory so the rest of the script operates there
    cd "$TARGET_DIR" || {
        log "❌ Failed to cd into $TARGET_DIR"
        exit 1
    }


    # Update SCRIPT_DIR to the new runtime location so the rest of the script uses it
    SCRIPT_DIR="$(pwd)"
    log "📂 Now operating in $SCRIPT_DIR"
}


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
# Find first notebook (ignore *_warning.ipynb)
# Create one if none exists
# --------------------------------------------------
find_notebook() {
    NOTEBOOK=$(ls *.ipynb 2>/dev/null | grep -v '_warning.ipynb' | head -n 1)

    if [ -z "$NOTEBOOK" ]; then
        PROJECT_NAME="$(basename "$PWD")"
        NOTEBOOK="${PROJECT_NAME}.ipynb"

        log "📓 No notebook found — creating ${NOTEBOOK}..."

        META_FILE="create_empty_notebook.py"

        cat > "$META_FILE" <<EOPY
import nbformat

nb = nbformat.v4.new_notebook(
    cells=[
        nbformat.v4.new_markdown_cell(
            "# ${PROJECT_NAME}\n\n"
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

with open("${NOTEBOOK}", "w", encoding="utf-8") as f:
    nbformat.write(nb, f)
EOPY

        uv run python "$META_FILE"
        rm -f "$META_FILE"

        log "✅ Created ${NOTEBOOK}"
    else
        log "📓 First notebook found: $NOTEBOOK"
    fi
}




# --------------------------------------------------
# Enforce single running instance
# --------------------------------------------------
enforce_single_instance() {
    log "Checking for previous Jupyter instance..."
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            if ps -p "$OLD_PID" -o comm= | grep -qi jupyter; then
                log "🛑 Stopping previous Jupyter (PID $OLD_PID)..."
                kill "$OLD_PID" || true
                sleep 2
            fi
        fi
        rm -f "$PID_FILE"
    fi
}

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

        # Use temporary Python file to inject Markdown as first notebook cell
        META_FILE="inject_warning.py"

        cat > "$META_FILE" <<EOPY
import nbformat
from pathlib import Path

NOTEBOOK_FILE = "$NOTEBOOK_WARNING"
WARNING_FILE = "$WARNING_FILE"
MARKER = "<!-- SYSTEM DEPENDENCY WARNING -->"

# Read notebook
nb = nbformat.read(NOTEBOOK_FILE, as_version=4)

# Check if warning cell already exists
for cell in nb.cells:
    if cell.cell_type == "markdown" and MARKER in cell.source:
        break
else:
    # Read warning content
    warning_text = Path(WARNING_FILE).read_text()
    warning_text = f"{MARKER}\\n\\n{warning_text}"

    # Insert as first cell
    warning_cell = nbformat.v4.new_markdown_cell(warning_text)
    nb.cells.insert(0, warning_cell)

    # Save notebook
    nbformat.write(nb, NOTEBOOK_FILE)
EOPY

        # Run the script using your known Python environment
        uv run python "$META_FILE"
        rm -f "$META_FILE"

    else
        # Remove warning file if no warnings exist
        if [ -n "$WARNING_FILE" ] && [ -f "$WARNING_FILE" ]; then
            log "Removing warning file..."
            rm -f "$WARNING_FILE"
        fi
    fi
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
    META_FILE="meta_update.py"

    cat > "$META_FILE" <<EOPY
import json

nb_file = "$NOTEBOOK"

with open(nb_file, "r", encoding="utf-8") as f:
    nb = json.load(f)

nb['metadata']['kernelspec'] = {
    "name": "$KERNEL_NAME",
    "display_name": "$KERNEL_DISPLAY",
    "language": "python"
}

with open(nb_file, "w", encoding="utf-8") as f:
    json.dump(nb, f, indent=2)
EOPY

    uv run python "$META_FILE"
    rm -f "$META_FILE"
}

# --------------------------------------------------
# Launch Jupyter Lab
# --------------------------------------------------
launch_jupyter() {
    export JUPYTER_DISABLE_CONFIG=1
    log "🌐 Launching Jupyter Lab..."
    nohup uv run jupyter lab "$NOTEBOOK" >/dev/null 2>&1 &
    NEW_PID=$!
    echo "$NEW_PID" > "$PID_FILE"
    log "✅ Jupyter running (PID $NEW_PID)"
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

# ==================================================
# Main execution
# ==================================================
log "=================================================="
log "🚀 Starting Jupyter Notebook App"
log "📁 Directory: $SCRIPT_DIR"
log "--------------------------------------------------"

require_mac_os
check_for_updates
create_local_runtime
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
log "=================================================="

exit 0
