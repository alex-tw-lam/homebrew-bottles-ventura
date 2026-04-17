# Homebrew Bottles — macOS 13 Ventura (Intel x86_64)

Build bottles on GitHub Actions for packages needing source compilation on macOS 13 Ventura Intel. Uses a **Tart macOS 13 VM** on Apple Silicon runners + Rosetta 2 to guarantee exact SDK compatibility.

## Usage

From MacBook 12 (auto-detect + build + install):

    ./scripts/build-queue.sh

From MacBook 12 (specific packages):

    ./scripts/build-queue.sh llvm go rust

From any device (manual trigger):

    gh workflow run build-bottle.yml -R alex-tw-lam/homebrew-bottles-ventura -f detect_mode=true -f packages="llvm go rust"

Watch + install manually:

    gh run watch <run_id> -R alex-tw-lam/homebrew-bottles-ventura
    ./scripts/install-bottles.sh <run_id>

## Target
- MacBook 12, Intel i7-7Y75, macOS 13.7.8, Homebrew 5.1.6, CLT 14.3.1, Clang 14.0.3
