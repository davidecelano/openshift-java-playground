#!/bin/bash
# Update image references in all deployment manifests

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <new-registry>"
  echo "Example: $0 quay.io/myorg"
  exit 1
fi

NEW_REGISTRY="$1"
OLD_PATTERN="quay.io/yourorg"

echo "Updating image references from '${OLD_PATTERN}' to '${NEW_REGISTRY}'..."
echo ""

find . -name "deployment-*.yaml" -type f | while read -r file; do
  echo "Updating ${file}..."
  sed -i "s|${OLD_PATTERN}|${NEW_REGISTRY}|g" "${file}"
done

echo ""
echo "Update complete! Verify changes:"
echo "  git diff"
