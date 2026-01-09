# Jupyter Project Launcher (`run.command`)

## Motivation

This project includes a **macOS-specific launcher (`run.command`)** designed to make running Jupyter notebooks:

* **Reliable**
* **Reproducible**
* **Safe to share**
* **Non-destructive to the original files**

Many notebooks are shared via **Dropbox**, email, or shared folders.
Running Python environments directly inside shared directories can easily:

* Pollute the folder with `.venv/`, `.ipynb_checkpoints/`, `pyproject.toml`
* Break paths when opened by another user
* Corrupt or silently modify shared notebooks
* Leave behind stale Jupyter kernels pointing to deleted environments

`run.command` solves this by **creating a local working copy** and running everything from there.

---

## High-Level Behavior

### When run from a Dropbox (or any shared) folder

* A local project directory is created at:

```
~/notebooks/<project_name>
```

* Files are **copied**, not modified in place
* All generated files live **only in the local directory**
* The original shared folder remains untouched

### When run from `~/notebooks/<project_name>`

* No copy occurs
* The script runs **in place**
* Safe to re-run any number of times
* Idempotent: environments and kernels are recreated as needed

---

## Why This Matters

* Dropbox sync + virtual environments is a foot-gun
* Jupyter kernels store **absolute paths**
* `.venv` directories are machine-specific
* Notebook checkpoints should never be shared

This design ensures:

> **Shared files stay clean. Local execution stays local.**

---

## macOS-Specific Design

This launcher is intentionally macOS-only.

It relies on:

* `run.command` (Finder-clickable shell script)
* Homebrew (optional system dependencies)
* `uv` for Python + environment management
* Standard macOS filesystem layout

Double-clicking `run.command` in Finder is the expected entry point.

---

## Directory Layout (Local)

After first run, your local project directory will look like:

```
~/notebooks/<project_name>/
├── run.command
├── requirements.txt
├── brew.txt
├── notebook.ipynb
├── notebook_warning.ipynb   (optional)
├── pyproject.toml
├── .venv/
├── .ipynb_checkpoints/
└── log.txt                  (optional)
```

Only this directory is modified.

---

## Setup Files

### Required

#### `run.command`

The launcher itself.

* Entry point
* Safe to double-click
* Can be re-run at any time
* Handles setup, environment, kernel registration, and launch

---

### Optional but Recommended

#### `requirements.txt`

Python dependencies.

Example:

```
numpy
pandas
matplotlib
scanpy
```

Automatically imported into the local virtual environment.

---

#### `brew.txt`

System-level dependencies (macOS).

Example:

```
graphviz
ffmpeg
hdf5
```

If any are missing:

* A `_warning.ipynb` is generated
* Jupyter opens the warning notebook first
* The original notebook remains untouched

---

#### `*.ipynb`

One or more Jupyter notebooks.

* The **first non-warning notebook** is launched by default
* Warning notebooks are auto-generated when needed
* Original notebooks are never modified in shared folders

---

## Warning Notebook Behavior

If required system dependencies are missing:

* A copy of the notebook is created as:

  ```
  <notebook>_warning.ipynb
  ```
* A **readable Markdown warning** is injected as the first cell
* The warning notebook is opened instead of the original
* Once dependencies are fixed, rerunning `run.command` restores normal behavior

This keeps warnings visible **without corrupting real work**.

---

## Re-Running Safely

You can rerun `run.command` at any time:

* Existing Jupyter instances are stopped
* Kernels are deleted and recreated
* Environments are reused when valid
* No duplicate state accumulates

Re-running is encouraged.

---

## Summary

**`run.command` exists to make notebooks:**

* Shareable
* Safe
* Predictable
* Zero-setup for collaborators

> **Shared folders are read-only sources.
> Local folders are execution sandboxes.**

That separation is intentional.

---

## Questions or Extensions

Common extensions include:

* Adding dataset validation
* Locking Python versions
* Enforcing read-only warning notebooks
* Multi-user kernel isolation

All are compatible with this design.

---

Happy hacking 🧠🧪

