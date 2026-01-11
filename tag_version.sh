#!/bin/bash
VERSION_FILE="launch_jupyter.src" 
COMMAND_FILE="launch_jupyter.command"

# Git commit, tag, and push
git add "$VERSION_FILE"
git add "$COMMAND_FILE"
git commit -m "Bump version to $NEW_VERSION"
git tag "v$NEW_VERSION"
git push
git push --tags

