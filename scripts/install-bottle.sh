#!/bin/bash
set -euo pipefail
# Usage: install-bottle.sh <run_id> <package_name> [repo]

RUN_ID="${1:?Usage: install-bottle.sh <run_id> <package_name>}"
PKG_NAME="${2:?Usage: install-bottle.sh <run_id> <package_name>}"
REPO="${3:-alex-tw-lam/homebrew-bottles-ventura}"
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT

ARTIFACT_NAME="forged-bottle-${PKG_NAME}-${RUN_ID}"

echo "=== Installing forged bottle for $PKG_NAME from run $RUN_ID ==="
echo "Downloading artifact: $ARTIFACT_NAME"

if ! gh run download "$RUN_ID" -R "$REPO" -n "$ARTIFACT_NAME" -D "$D"; then
    echo "::error::Failed to download artifact '$ARTIFACT_NAME'. Please check if the run ID and package name are correct."
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

echo "Attempting to install via Plan B (manual extraction)..."
cellar_dir=$(brew --cellar)
if [ ! -d "$cellar_dir" ]; then
    echo "::error::Homebrew Cellar not found at '$cellar_dir'"
    exit 1
fi

echo "Extracting to $cellar_dir"
tar -xzf "$BOTTLE_PATH" -C "$cellar_dir"

pkg_dir_in_cellar=$(basename "$BOTTLE_PATH" | sed -e 's/\.ventura\.bottle.*//' -e 's/--/ /' | awk '{print $1}')
echo "Linking '$pkg_dir_in_cellar'..."

if brew link --overwrite "$pkg_dir_in_cellar"; then
    echo "✅ Success! '$PKG_NAME' installed via manual extraction."
    echo "Pinning package to prevent accidental upgrades..."
    brew pin "$PKG_NAME"
else
    echo "❌ FAILED to link the package."
    exit 1
fi
