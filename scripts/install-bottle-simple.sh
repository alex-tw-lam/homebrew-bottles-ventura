#!/bin/bash
set -euo pipefail
# Usage: install-bottle-simple.sh <run_id> <package_name> [repo]

RUN_ID="${1:?Usage: install-bottle-simple.sh <run_id> <package_name>}"
PKG_NAME="${2:?Usage: install-bottle-simple.sh <run_id> <package_name>}"
REPO="${3:-alex-tw-lam/homebrew-bottles-ventura}"
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT

ARTIFACT_NAME="forged-bottle-${PKG_NAME}-${RUN_ID}"

echo "=== Testing simple 'brew install' with forged bottle for $PKG_NAME from run $RUN_ID ==="
echo "Downloading artifact: $ARTIFACT_NAME"

if ! gh run download "$RUN_ID" -R "$REPO" -n "$ARTIFACT_NAME" -D "$D"; then
    echo "::error::Failed to download artifact '$ARTIFACT_NAME'."
    exit 1
fi

shopt -s nullglob
bottle_file=("$D/"*.ventura.bottle*.tar.gz)
if [ ${#bottle_file[@]} -eq 0 ]; then
    echo "::error::No forged bottle found in downloaded artifact."
    exit 1
fi

BOTTLE_PATH="${bottle_file[0]}"
echo "Found bottle: $(basename "$BOTTLE_PATH")"

echo "Attempting to install with 'brew install'..."
if brew install "$BOTTLE_PATH"; then
    echo "✅ SUCCESS! 'brew install' worked on the forged bottle!"
    brew pin "$PKG_NAME"
else
    echo "❌ FAILURE. 'brew install' rejected the forged bottle."
    exit 1
fi
