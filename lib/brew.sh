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