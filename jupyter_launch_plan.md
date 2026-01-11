# Refactor Plan: `launch_jupyter.command`

Based on `GEMINI.md`, this plan details the structural refactoring of the monolithic `launch_jupyter.command` into a modular, testable bash project.

## 1. Project Structure

The existing single-file script will be exploded into the following structure:

```text
jupyter_launcher/
├── bin/
│   └── launch_jupyter          # Main Orchestrator (entry point logic)
├── lib/
│   ├── log.sh                  # Logging utilities
│   ├── os.sh                   # OS capabilities & UI interactions
│   ├── github.sh               # GitHub API, updates
│   ├── runtime.sh              # Runtime setup (copier, single instance)
│   ├── python.sh               # Python env management (uv, venv)
│   ├── notebook.sh             # Notebook finding & launching
│   └── brew.sh                 # Homebrew dependency checks
├── python/
│   ├── create_notebook.py      # Extracted from find_notebook
│   ├── inject_warning.py       # Extracted from check_brew_dependencies
│   └── update_metadata.py      # Extracted from update_notebook_metadata
├── tests/
│   ├── test_github.bats
│   ├── test_python.bats
│   ├── test_notebook.bats
│   └── ...
└── launch_jupyter.command      # Thin wrapper (cd & exec)
```

## 2. Module Decomposition

### `lib/log.sh`
- **Functions**: `log`
- **Dependencies**: None (Uses `LOG_FILE` global).

### `lib/os.sh`
- **Functions**:
    - `require_mac_os`
    - `require_curl`
    - `mac_confirm_update`
- **Dependencies**: `log`

### `lib/github.sh`
- **Functions**:
    - `get_latest_github_tag`
    - `download_run_command`
    - `check_for_updates`
- **Dependencies**: `require_curl`, `mac_confirm_update`, `log`, `REPO_*` globals.
- **Note**: `download_run_command` logic currently downloads a single file. For the refactor to stick across updates, this mechanism might need review, but we will preserve exact runtime behavior for now (downloading the command file), noting that a future "Architecture V2" update might be needed for distributing multi-file apps.

### `lib/runtime.sh`
- **Functions**:
    - `enforce_single_instance`
    - `create_local_runtime`
- **Dependencies**: `log`, `PID_FILE`, `SCRIPT_DIR` globals.
- **Updates Required**: `create_local_runtime` must be updated to copy the new `bin`, `lib`, and `python` directories to the target, not just the single command file.

### `lib/python.sh`
- **Functions**:
    - `install_uv`
    - `determine_python_version`
    - `ensure_python`
    - `init_uv_project`
    - `create_venv`
    - `sync_dependencies`
    - `ensure_ipykernel`
- **Dependencies**: `log`, `PY_VERSION` globals.

### `lib/notebook.sh`
- **Functions**:
    - `find_notebook`
    - `register_kernel`
    - `launch_jupyter`
    - `update_notebook_metadata`
- **Dependencies**: `log`, `python/` scripts.

### `lib/brew.sh`
- **Functions**:
    - `check_brew_dependencies`
- **Dependencies**: `log`, `python/inject_warning.py` script.

## 3. Python Helper Extraction

Three embedded python scripts (heredocs) will be moved to standalone files in `python/` to improve readability and allow separate testing:
1.  `create_empty_notebook.py` -> `python/create_notebook.py`
2.  `inject_warning.py` -> `python/inject_warning.py`
3.  `meta_update.py` -> `python/update_metadata.py`

The bash scripts will be updated to call these files using `uv run python python/<script_name>` instead of `cat > ...`.

## 4. Execution Logic (`bin/launch_jupyter`)

The main orchestrator will replace the bottom "Main execution" block of the original script.

**Flow:**
1.  Source all `lib/*.sh` modules.
2.  Define globals (`SCRIPT_DIR`, `REPO_STUFF`, etc).
3.  Execute the sequence:
    ```bash
    log_header
    require_mac_os
    check_for_updates
    create_local_runtime # Recursive call handling needs care here
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
    log_footer
    ```

## 5. Implementation Strategy

1.  **Setup**: Create directory tree.
2.  **Extract Python**: Create `python/*.py` files from current heredocs.
3.  **Create Libs**: Create `lib/*.sh` and populate with functions.
    - *Constraint check*: Ensure no global bleeding or missing variables.
4.  **Create Orchestrator**: Build `bin/launch_jupyter` assembling the pieces.
5.  **Create Wrapper**: Overwrite `launch_jupyter.command` with the thin wrapper.
6.  **Safety Verification**: Ensure `create_local_runtime` correctly copies the new structure to `~/notebooks/project`.
7.  **Tests**: Generate BATS tests for each module in `tests/`.

## 6. Verification

- Run the new wrapper.
- Verify it copies effectively to `~/notebooks/jupyter_launcher`.
- Verify it launches Jupyter Lab.
