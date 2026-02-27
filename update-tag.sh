#!/bin/bash

# Exit on any error
set -e

# Check if a tag name was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <tag-name>"
  exit 1
fi

TAG="$1"

git pull origin --tags

# Delete local tag if it exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag -d "$TAG"
fi

# Delete remote tag
git push origin --delete "$TAG" || true

# Create new tag on current commit
git tag "$TAG"

# Push new tag to origin
git push origin "$TAG"

echo "Tag '$TAG' has been recreated on the latest commit and pushed to origin."