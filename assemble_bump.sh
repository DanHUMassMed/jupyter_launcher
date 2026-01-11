#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/bump_version.sh"
"$SCRIPT_DIR/assemble_command.sh"
"$SCRIPT_DIR/tag_version.sh"
