#!/bin/bash
set -euo pipefail
# Run on MacBook 12 to detect, trigger, watch, and install
# Usage: build-queue.sh [package1 package2 ...]
#   With no args: checks all outdated formulae
#   With args: only checks specified packages

REPO="alex-tw-lam/homebrew-bottles-ventura"

echo "=== Homebrew Bottle Build Queue ==="

if [ $# -gt 0 ]; then
  check_list="$*"
else
  check_list=$(brew outdated --formula --quiet 2>/dev/null)
fi

[ -z "$check_list" ] && { echo "Nothing to update"; exit 0; }

# V7: Check which need compilation
needs_compile=()
for pkg in $check_list; do
  if brew fetch --bottle-tag=ventura "$pkg" 2>/dev/null; then
    echo "  [bottle] $pkg"
  else
    echo "  [compile] $pkg"
    needs_compile+=("$pkg")
  fi
done

[ ${#needs_compile[@]} -eq 0 ] && { echo "All packages have bottles. Run: brew upgrade"; exit 0; }

echo "${#needs_compile[@]} packages need compilation"

# Topological sort
ordered=$(brew deps --topological "${needs_compile[@]}" 2>/dev/null || printf '%s\n' "${needs_compile[@]}")
final=()
while IFS= read -r pkg; do
  for nc in "${needs_compile[@]}"; do
    [ "$pkg" = "$nc" ] && { final+=("$pkg"); break; }
  done
done <<< "$ordered"
for nc in "${needs_compile[@]}"; do
  skip=false
  for f in "${final[@]}"; do [ "$f" = "$nc" ] && skip=true && break; done
  $skip || final+=("$nc")
done

pkg_str=$(printf '%s ' "${final[@]}")
echo "Build order: $pkg_str"

# Trigger (pass list to runner for re-check)
echo "Triggering..."
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
