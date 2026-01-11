Here’s a **real PRD** you could hand to an engineer (or an AI agent) and actually get a usable system out of it.

---

# **Product Requirements Document**

## **AI-Assisted Bash Refactor for `launch_jupyter.command`**

---

## **1. Purpose**

The goal of this system is to take a **large, monolithic Bash script** (specifically `launch_jupyter.command`) and transform it into a **modular, testable, maintainable Bash project** without breaking functionality.

The assistant must:

* Preserve exact runtime behavior
* Improve structure
* Enable unit testing
* Enable future evolution
* Maintain shell compatibility (macOS + bash)

This is not a rewrite — it is a **structural refactor with correctness guarantees**.

---

## **2. Problem Statement**

The current script:

* Is ~1000 lines long
* Mixes concerns (networking, OS detection, Python setup, UI, notebook logic)
* Cannot be tested except by running the full script
* Is hard to reason about or safely change

Yet it is already sophisticated:

* Self-updating
* Idempotent
* Environment-aware
* UI-integrated
* State-dependent

This is **beyond “just a shell script”** — it is infrastructure.

We need tooling that makes it behave like a real software project.

---

## **3. Target Architecture**

The assistant must produce this structure:

```
jupyter_launcher/
├── bin/
│   └── launch_jupyter
├── lib/
│   ├── log.sh
│   ├── os.sh
│   ├── github.sh
│   ├── python.sh
│   ├── notebook.sh
│   ├── brew.sh
│   └── runtime.sh
├── python/
│   ├── create_notebook.py
│   ├── inject_warning.py
│   └── update_metadata.py
├── tests/
│   ├── test_github.bats
│   ├── test_python.bats
│   └── test_notebook.bats
└── launch_jupyter.command
```

Where:

`launch_jupyter.command` becomes:

```bash
#!/bin/bash
cd "$(dirname "$0")"
exec ./bin/launch_jupyter
```

and `bin/launch_jupyter` is the orchestrator.

---

## **4. Functional Requirements**

### 4.1 Decomposition Engine

The assistant must:

| Task                        | Requirement                                 |
| --------------------------- | ------------------------------------------- |
| Identify functions          | Parse all `function_name()` blocks          |
| Identify globals            | Extract shared state                        |
| Identify side effects       | I/O, filesystem, network, UI                |
| Classify responsibilities   | OS, Python, GitHub, notebooks, logging, etc |
| Assign functions to modules | Based on responsibility                     |
| Rewrite references          | Update globals, imports, and paths          |

---

### 4.2 Module Rules

Each file in `lib/` must:

* Contain related functions only
* Have no execution at load time
* Be safe to `source`
* Not call `exit`

Example:

`lib/github.sh` must include:

```bash
get_latest_github_tag
download_run_command
check_for_updates
```

and nothing else.

---

### 4.3 Orchestrator Generation

The AI must generate:

`bin/launch_jupyter`

Which:

* Sources all modules
* Executes functions in correct order
* Preserves logging and error semantics

The order must match the original script’s behavior exactly.

---

### 4.4 Test Harness Generation

The assistant must generate:

* A `tests/` directory
* BATS tests for each module

Each test must:

* Source the relevant `.sh` file
* Mock side effects
* Assert expected behavior

Example:

```bash
@test "get_latest_github_tag returns version string" {
  run get_latest_github_tag
  [[ "$output" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}
```

---

### 4.5 Safety Requirements

The system must guarantee:

* No function logic is altered
* No command semantics change
* No ordering changes
* No environment behavior changes

It must be a **semantic-preserving refactor**.

---

## **5. AI Workflow**

The assistant must operate in phases:

### Phase 1 — Static Analysis

* Build a dependency graph of functions & variables
* Identify coupling and side effects

### Phase 2 — Module Assignment

* Assign each function to a module
* Emit warnings for cross-module globals

### Phase 3 — Code Rewrite

* Rewrite into multiple files
* Rewrite references
* Generate orchestrator

### Phase 4 — Test Synthesis

* Generate BATS tests
* Mock network, filesystem, osascript

### Phase 5 — Validation

* Generate a script that:

  * Runs old script
  * Runs new script
  * Diffs output, logs, file changes

---

## **6. Non-Goals**

This system will NOT:

* Convert Bash to Python
* Change logic
* Optimize behavior
* Add new features

It is purely structural.

---

## **7. Why This Matters**

Your script is already:

* A package manager
* A launcher
* A deployment system

It deserves:

* Tests
* Modules
* CI
* Versioning
* Refactorability

This AI assistant is how you get there **without breaking users**.

