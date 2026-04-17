#!/bin/bash
set -euo pipefail
# Usage: build-queue.sh [package1 package2 ...]

REPO="alex-tw-lam/homebrew-bottles-ventura"

echo "=== Homebrew Bottle Build Queue (Tart VM) ==="

if [ $# -gt 0 ]; then
  check_list="$*"
else
  check_list=$(brew outdated --formula --quiet 2>/dev/null)
fi

[ -z "$check_list" ] && { echo "Nothing to update"; exit 0; }

# Trigger the Tart VM workflow (detect mode happens in the VM)
pkg_str=$(echo "$check_list" | tr '\n' ' ' | xargs)
echo "Triggering workflow for packages: $pkg_str"
gh workflow run build-bottle.yml -R "$REPO" -f detect_mode=true -f packages="$pkg_str"

sleep 5
run_id=$(gh run list -R "$REPO" --limit 1 --json databaseId -q '.[0].databaseId')
echo "Run ID: $run_id"

# Watch
echo "Watching build..."
gh run watch "$run_id" -R "$REPO" --exit-status || {
  echo "Build failed. Check: gh run view $run_id -R $REPO --log-failed"
  exit 1
}

# Install
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/install-bottles.sh" "$run_id"
