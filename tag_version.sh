#!/bin/bash
VERSION_FILE="launch_jupyter.src" 
COMMAND_FILE="launch_jupyter.command"

VERSION_LINE=$(grep VERSION_LINE $VERSION_FILE)
VERSION=$(echo "$VERSION_LINE" | sed 's/.*CURRENT_VERSION=v\([0-9.]*\).*/\1/')

# Git commit, tag, and push
git add "$VERSION_FILE"
git add "$COMMAND_FILE"
git commit -m "Bump version to $VERSION"
git tag "v$VERSION"
git push
git push --tags
