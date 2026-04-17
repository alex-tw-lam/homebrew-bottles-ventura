#!/bin/bash
set -euo pipefail
# Usage: install-bottle.sh <run_id> <package_name> [repo]
#
# Installs a forged Ventura bottle using native `brew install`.
# Requires: HOMEBREW_DEVELOPER=1 to bypass local-path restriction,
#           --force-bottle to accept cross-OS bottles.

RUN_ID="${1:?Usage: install-bottle.sh <run_id> <package_name>}"
PKG_NAME="${2:?Usage: install-bottle.sh <run_id> <package_name>}"
REPO="${3:-alex-tw-lam/homebrew-bottles-ventura}"
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT

ARTIFACT_NAME="forged-bottle-${PKG_NAME}-${RUN_ID}"

echo "=== Installing forged bottle for $PKG_NAME from run $RUN_ID ==="
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

echo "Installing via native brew install (HOMEBREW_DEVELOPER=1 + --force-bottle)..."
if HOMEBREW_DEVELOPER=1 brew install --force-bottle "$BOTTLE_PATH"; then
    echo "✅ Success! '$PKG_NAME' installed via native brew install."
else
    echo "❌ brew install failed. Falling back to manual extraction..."
    cellar_dir=$(brew --cellar)
    tar -xpf "$BOTTLE_PATH" -C "$cellar_dir"
    brew link --overwrite "$PKG_NAME"
    brew pin "$PKG_NAME"
    echo "✅ Installed via fallback (manual extraction + pin)."
fi
