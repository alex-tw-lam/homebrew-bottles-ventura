#!/bin/bash
set -euo pipefail
# Usage: install-bottles.sh <run_id> [repo]
RUN_ID="${1:?Usage: install-bottles.sh <run_id> [repo]}"
REPO="${2:-alex-tw-lam/homebrew-bottles-ventura}"
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT

echo "=== Installing bottles from run $RUN_ID ($REPO) ==="
gh run download "$RUN_ID" -R "$REPO" -n "bottles-${RUN_ID}" -D "$D/bottles"
gh run download "$RUN_ID" -R "$REPO" -n "manifest-${RUN_ID}" -D "$D/manifest" 2>/dev/null || true

shopt -s nullglob
bottles=("$D/bottles/"*.ventura.bottle.tar.gz)
[ ${#bottles[@]} -eq 0 ] && { echo "ERROR: No bottles found"; exit 1; }
echo "Found ${#bottles[@]} bottles"

# V6b: Verify checksums
if [ -f "$D/manifest/build-manifest.json" ]; then
  echo "Verifying checksums (V6b)..."
  python3 - "$D/manifest/build-manifest.json" "$D/bottles" << 'PYEOF'
import json, hashlib, glob, sys
m = json.load(open(sys.argv[1]))
err = 0
for p in m.get('packages', []):
    f = glob.glob(sys.argv[2] + '/' + p['name'] + '--*.ventura.bottle.tar.gz')
    if not f:
        continue
    a = hashlib.sha256(open(f[0], 'rb').read()).hexdigest()
    if a != p['sha256']:
        print(f'FAIL {p["name"]}')
        err += 1
    else:
        print(f'  OK {p["name"]}')
sys.exit(1 if err else 0)
PYEOF
fi

# Install each bottle
for b in "${bottles[@]}"; do
  name=$(basename "$b" | sed 's/--.*//')
  echo "Installing $name..."
  if brew install "$b"; then
    ver=$(brew info --json=v2 "$name" 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d['formulae'][0]['installed'][0]['version'])
except Exception:
    print('UNKNOWN')
" 2>/dev/null || echo "?")
    echo "  OK: $name @ $ver"
  else
    echo "  FAILED: $name"
    exit 1
  fi
done
echo "=== All bottles installed ==="
