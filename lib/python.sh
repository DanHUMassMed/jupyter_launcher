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
