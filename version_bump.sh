#!/bin/bash
VERSION_FILE="run.command" 

VERSION_LINE=$(grep CURRENT_VERSION $VERSION_FILE)

VERSION=$(echo "$VERSION_LINE" | sed 's/.*CURRENT_VERSION=v\([0-9.]*\).*/\1/')

if [ -z "$VERSION" ]; then
  echo "❌ Could not find version in $VERSION_FILE"
  exit 1
fi

# Split into MAJOR.MINOR.PATCH
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

# Increment patch by default
NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"

echo "Bumping version: $VERSION → $NEW_VERSION"

# Detect GNU vs BSD sed
if sed --version >/dev/null 2>&1; then
  # GNU sed (Ubuntu/Linux)
  sed -i "s|CURRENT_VERSION=$VERSION|CURRENT_VERSION=$NEW_VERSION|" "$VERSION_FILE"
else
  # BSD sed (macOS)
  sed -i '' "s|CURRENT_VERSION=$VERSION|CURRENT_VERSION=$NEW_VERSION|" "$VERSION_FILE"
fi

# Git commit, tag, and push
git add "$VERSION_FILE"
git commit -m "Bump version to $NEW_VERSION"
git tag "v$NEW_VERSION"
git push
git push --tags

