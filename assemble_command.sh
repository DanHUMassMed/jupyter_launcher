#!/bin/bash
set -e

# Configuration
OUTPUT_FILE="launch_jupyter.command"
BIN_FILE="launch_jupyter.src"
LIB_DIR="lib"

# Library files in dependency order
LIBS=(
    "log.sh"
    "os.sh"
    "github.sh"
    "python.sh"
    "runtime.sh"
    "brew.sh"
    "notebook.sh"
)

echo "🔨 assembling ${OUTPUT_FILE}..."

# 1. Header (everything before '# End Configuration')
# We use awk to print lines until we see the marker
echo "   - extract header from ${BIN_FILE}"
awk '/# End Configuration/ {exit} {print}' "${BIN_FILE}" > "${OUTPUT_FILE}"

echo "" >> "${OUTPUT_FILE}"
echo "# ==================================================" >> "${OUTPUT_FILE}"
echo "# EMBEDDED LIBRARIES" >> "${OUTPUT_FILE}"
echo "# ==================================================" >> "${OUTPUT_FILE}"
echo "" >> "${OUTPUT_FILE}"

# 2. Libraries
for lib in "${LIBS[@]}"; do
    lib_path="${LIB_DIR}/${lib}"
    if [ -f "${lib_path}" ]; then
        echo "   - embedding ${lib_path}"
        echo "# *** START ${lib} ***" >> "${OUTPUT_FILE}"
        cat "${lib_path}" >> "${OUTPUT_FILE}"
        echo "" >> "${OUTPUT_FILE}"
        echo "# *** END ${lib} ***" >> "${OUTPUT_FILE}"
        echo "" >> "${OUTPUT_FILE}"
    else
        echo "❌ Error: Library ${lib_path} not found!"
        exit 1
    fi
done


echo "# ==================================================" >> "${OUTPUT_FILE}"

# 3. Footer (everything from '# Main Execution Flow')
echo "   - extract footer from ${BIN_FILE}"
awk '/# Main Execution Flow/ {flag=1} flag {print}' "${BIN_FILE}" >> "${OUTPUT_FILE}"

# 4. Finalize
chmod +x "${OUTPUT_FILE}"
echo "✅ Done! Created ${OUTPUT_FILE}"
