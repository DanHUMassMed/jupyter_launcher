Absolutely — here’s your **updated User Guide** with emojis and the requested Dropbox note. I also updated `source_dir.json` with the new path.

---

# **🧠 Jupyter Project Launcher User Guide**

This guide explains how to use and develop with the macOS-specific **`launch_jupyter.command`** launcher for safely running Jupyter notebooks in shared or local directories.

---

## **Section 1: 🏃 Users – Running Notebooks**

This section is for collaborators or team members who **just want to run the notebooks**.

### **🚀 Launching Jupyter**

You can launch the notebooks by:

1. **Double-clicking `launch_jupyter.command`** in Finder, or
2. **Running from the command line**:

```bash
cd ~/notebooks/<project_name>
./launch_jupyter.command
```

> This will automatically:
>
> * Pick a free port for Jupyter 🖥️
> * Start a local virtual environment 🐍
> * Launch the first notebook in a browser 🌐
> * Pop a macOS notification if something goes wrong 🔔

---

### **🛡️ How it Works for Users**

* If this is your **first run**, a local working copy is created at:

```
~/notebooks/<project_name>
```

* Files are copied, **original shared folders remain untouched** 📁
* The launcher handles **stopping old Jupyter instances** automatically ✋
* You can safely **rerun the launcher** at any time; local notebooks are preserved 💾

---

### **⚠️ Notifications and Errors**

* **Success:** Your default browser opens the notebook automatically 🌐
* **Failure:** A macOS notification pops up if the URL or server fails to start 🔔
* **Logs:** Check `~/notebooks/<project_name>/log.txt` for details 📄

---

## **Section 2: 🛠️ Developers – Preparing Notebooks for Others**

This section is for people creating or maintaining notebooks that will be shared with other users.

---

### **📂 Required Setup Files**

1. **`requirements.txt`** – Python dependencies for the notebook.
   Example:

   ```
   numpy
   pandas
   matplotlib
   scanpy
   ```
2. **`version.txt`** – Python version to use in the environment.
   Example:

   ```
   python=3.13
   ```
3. **`brew.txt`** – macOS system dependencies.
   Example:

   ```
   graphviz
   ffmpeg
   hdf5
   ```
4. **`source_dir.json`** – Specifies relative access to shared data for notebooks.

   Example:

   ```json
   {
       "SOURCE_DIR": "/Users/dan/Dropbox/Daniel Higgins/Walker_lab_shared/Bioinformatics_parent/NuTRAP_112025/PCA-Plot"
   }
   ```

---

### **💡 Why `source_dir.json` Matters**

* Users’ **local paths to Dropbox may differ** from yours when they run the notebooks
* Hardcoding paths breaks portability
* Using `source_dir.json` ensures notebooks **always know where the shared data lives**, regardless of local folder layout

---

### **📖 Using `source_dir.json` in Notebooks**

```python
import json
from pathlib import Path

data = json.load(open("source_dir.json"))
SOURCE_DIR = data["SOURCE_DIR"]
SOURCE_PATH = Path(SOURCE_DIR).resolve()
print(SOURCE_PATH)

# Example for relative access
nutrap_dir = SOURCE_PATH.parents[1]
```

---
---

## **📂 The `data/` Directory (Portable Data for Notebooks)**

Developers may include a **`data/`** directory next to their notebook.

If it exists, `launch_jupyter.command` will:

* **Copy the entire `data/` folder** into the user’s local runtime directory
* Preserve its structure and contents
* Make it available to the notebook via **relative paths**

Example project layout:

```
MyProject/
├── notebook.ipynb
├── requirements.txt
├── brew.txt
├── version.txt
└── data/
    ├── counts.csv
    ├── metadata.tsv
    └── images/
```

On the user’s machine this becomes:

```
~/notebooks/MyProject/
├── notebook.ipynb
└── data/
    ├── counts.csv
    ├── metadata.tsv
    └── images/
```

Your notebook can now load files simply with:

```python
from pathlib import Path

DATA = Path("data")

counts = DATA / "counts.csv"
metadata = DATA / "metadata.tsv"
```

No absolute paths.
No Dropbox paths.
No configuration files.

Just portable, relative access.

---

## **⚠️ Important: Data Is Copied**

The `data/` directory is **copied**, not linked.

This makes notebooks:

* Fully self-contained
* Portable across machines
* Safe to modify without touching shared storage

But it also means:

> **Do NOT put large datasets in `data/`.**

Good candidates for `data/`:

* Example datasets
* Small reference tables
* Test FASTQ files
* Example images
* Gene lists
* Metadata

Bad candidates:

* Raw sequencing runs
* Multi-GB imaging data
* Large HDF5 matrices
* Anything you wouldn’t want duplicated per user

For large datasets, use `source_dir.json` storage and load them dynamically inside the notebook.

---

## **🧠 Best Practices for Developers**

* Use `data/` for **small, shareable, reproducible datasets** 📁
* Always access files using **relative paths** (`Path("data") / "file.csv"`)
* Never hardcode absolute paths 🧯
* Assume every user gets their **own private copy** of `data/`
* Test locally by running `launch_jupyter.command` before sharing 🧪
* Include all dependencies in `requirements.txt` and `brew.txt` ✅
* Original notebooks remain in shared folders
* Update `version.txt` if your notebook requires a specific Python version 🐍

This model keeps your notebooks:

**Portable · Safe · Predictable · Easy for non-technical users**


---

### **⚠️ Warning Notebook Behavior**

* If system dependencies from `brew.txt` are missing, the launcher creates:

```
<notebook>_warning.ipynb
```

* A Markdown cell explains the missing dependencies 📝
* Users open this notebook first, ensuring warnings are visible **without modifying the original notebooks**

---

### **🔄 Reproducibility Tips**

* Rerun `launch_jupyter.command` after updating:

  * `requirements.txt`
  * `brew.txt`
  * Adding or modifying notebooks
* Local sandboxes are **idempotent**: rerunning won’t pollute shared directories or duplicate environments

---

## **📌 Summary**

* **Users 🏃:** Double-click or run `launch_jupyter.command` — work stays local, safe, and predictable
* **Developers 🛠️:** Include `requirements.txt`, `version.txt`, `brew.txt`, and `source_dir.json` for portability
* **Key Principle:** Shared folders are **read-only sources**; local folders are **execution sandboxes** ✅

> This ensures **reproducibility, safety, and predictable execution** for all users.

---

I can also make a **visual cheat sheet with emojis for launch, logs, warnings, and notifications** — perfect for non-technical collaborators.

Do you want me to create that?
