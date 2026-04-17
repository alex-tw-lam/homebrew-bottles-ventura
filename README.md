# Homebrew Bottles for Ventura — FINAL STATUS

## ⚠️ Project Archived

This project is **no longer needed**. The target MacBook 12 (2017, Intel i7-7Y75) has been successfully upgraded to macOS 14.8.5 Sonoma via [OCLP (OpenCore Legacy Patcher)](https://github.com/dortania/OpenCore-Legacy-Patcher/), which means Homebrew now provides native Sonoma bottles — no custom build pipeline required.

---

## What We Built

A GitHub Actions CI/CD pipeline that builds Homebrew bottles on newer macOS runners and installs them on the unsupported macOS 13 Ventura machine.

## Key Discoveries

These findings are documented for anyone trying to install Homebrew bottles on unsupported macOS versions:

### 1. `HOMEBREW_DEVELOPER=1` — The Magic Switch

Source: `Library/Homebrew/env_config.rb` line ~699

```ruby
def forbid_packages_from_paths?
  return false if ENV["HOMEBREW_INTERNAL_ALLOW_PACKAGES_FROM_PATHS"].present?
  return true if ENV["HOMEBREW_FORBID_PACKAGES_FROM_PATHS"].present?
  ENV["HOMEBREW_TESTS"].blank? && ENV["HOMEBREW_DEVELOPER"].blank?
end
```

By default, Homebrew **blocks** installing bottles from local file paths. `HOMEBREW_DEVELOPER=1` disables this restriction, allowing `FromBottleLoader` to recognize local `.tar.gz` files.

### 2. `--force-bottle` + `local_bottle_path` — Bypasses OS Check

Source: `Library/Homebrew/formula_installer.rb` lines 258-275

```ruby
def pour_bottle?(output_warning: false)
  return false if !formula.bottle_tag? && !formula.local_bottle_path
  return true  if force_bottle?              # <-- this
  # ... various checks skipped ...
  return true if formula.local_bottle_path.present?  # <-- and this
```

When `local_bottle_path` is set (from a local file), `pour_bottle?` returns `true`, **skipping all OS version validation**.

### 3. Tar Structure — The Silent Killer

Homebrew's `resolve_formula_names()` and `resolve_version()` parse the **first tar entry**:

```ruby
# utils/bottles.rb
def resolve_formula_names(bottle_file)
  name = bottle_file_list(bottle_file).first.to_s.split("/").fetch(0)
  # ...
end

def resolve_version(bottle_file)
  version = bottle_file_list(bottle_file).first.to_s.split("/").fetch(1)
  # ...
end
```

**The first tar entry MUST be `name/version/`** (e.g., `tree/2.3.2/`).

| Tar Structure | Result |
|---|---|
| `./` then `tree/` then `tree/2.3.2/` | ❌ `name="."` → "not a valid keg" |
| `tree/` then `tree/2.3.2/` | ❌ `version=""` → "index 1 outside of array bounds" |
| `tree/2.3.2/` | ✅ Works! |

### 4. Metadata Forging (狸貓換太子)

We modify `INSTALL_RECEIPT.json` inside the bottle to change:
- `sequoia` → `ventura`
- `macOS 15.x` → `macOS 13.0`

### 5. The Final Command

```bash
HOMEBREW_DEVELOPER=1 brew install --force-bottle /path/to/pkg--ver.ventura.bottle.N.tar.gz
```

This gives a **fully native `brew install` experience** — complete with `🍺`, pouring, cleanup, dependency resolution, and proper `brew info`/`brew doctor` output.

## Journey Summary

| Approach | Result |
|---|---|
| `brew install ./local.tar.gz` (default) | ❌ "requires the tap /var" |
| Tart VM on macOS runner | ❌ No nested virtualization |
| Rosetta 2 + macos-15 | Replaced by native Intel runner |
| `macos-13` runner | ❌ Deprecated, infinite queue |
| Manual extraction (霸王硬上弓) | ✅ Works but no `brew install` magic |
| `HOMEBREW_DEVELOPER=1` + `--force-bottle` + fixed tar | ✅ **Perfect native experience** |

## Credits

- Homebrew source code analysis: manual `grep` + `read` of `formulary.rb`, `formula_installer.rb`, `utils/bottles.rb`, `env_config.rb`
- CI pipeline: GitHub Actions on `macos-15-intel` runner
- Target machine: MacBook 12 (2017), Intel i7-7Y75, now running macOS 14.8.5 via OCLP
