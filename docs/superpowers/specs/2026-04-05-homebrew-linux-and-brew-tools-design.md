# Design: Homebrew for macOS & Linux + Migrate Cargo Tools to Homebrew

**Date:** 2026-04-05  
**Updated:** 2026-04-07  
**Status:** Approved

## Problem

- The dotfiles installer already installs Homebrew on macOS but not on Linux.
- On Linux with `--no-sudo-install`, there is no package manager fallback — system-level tools cannot be installed at all.
- Cargo-based tools (bat, eza, fd, rg, etc.) require Rust compilation, which is slow, fragile on remote servers, and duplicates what Homebrew provides as pre-built bottles.
- Python installation lacks a `--force-bottle` flag, causing libc compatibility issues on remote servers.

## Goals

1. Install Homebrew on **all platforms** (macOS, Linux+sudo, Linux+no-sudo).
2. Install Homebrew to `$HOME/.homebrew` on Linux (user-local, no sudo required).
3. Migrate all Cargo-installed CLI tools to Homebrew; keep Rust/cargo installed for manual use.
4. Support per-package install flags in the manifest (e.g., `--force-bottle` for Python).
5. Configure Homebrew in `zshrc` (version-controlled), not written to `~/.zprofile` by the installer.
6. Reorganize PATH priority: user-local bins → Homebrew → NVM → cargo.

## Out of Scope

- Removing Rust/rustup — cargo stays installed and available for manual use.
- Cargo cleanup (uninstalling old cargo-installed tools) — user does this manually or via a future dedicated script.
- Migrating apt system dependencies to Homebrew on Linux+sudo.

---

## Architecture

### Package manager routing

```
macOS                → brew install  (system packages from packages.darwin.list)
Linux + sudo         → apt install   (system packages from packages.linux.list)
                       brew install  (tools from brew.tools, including zsh)
Linux + no-sudo      → brew install  (system packages from packages.linux_brew.list)
                       brew install  (tools from brew.tools, including zsh)
```

### Homebrew prefix

| Platform | Prefix |
|----------|--------|
| macOS    | `/opt/homebrew` (Apple Silicon standard) |
| Linux    | `$HOME/.homebrew` |

### PATH priority (highest → lowest)

```
$HOME/.local/bin    ← user scripts/wrappers — override everything
$HOME/.scripts      ← user scripts
Homebrew            ← brew shellenv (bat, eza, rg, zsh, etc.)
NVM                 ← node version manager
cargo/bin           ← Rust toolchain (manual use)
system PATH
```

To achieve this order, zshrc loads in reverse (each prepend wins over the previous):
cargo → nvm → brew shellenv → `.scripts` → `.local/bin`

---

## Changes

> ⚠️ **Package name verification required:** The same tool may have different names across package
> managers (e.g., `libevent-dev` on apt vs `libevent` on Homebrew). All package lists below are
> **best-effort initial values** and must be validated against each registry during implementation.

### What the installer does differently

- **All modes** (including `--no-sudo-install`) now install system packages. Previously the no-sudo path skipped this step entirely; it now installs via Homebrew instead of apt. The user is prompted to confirm the brew package list before installation begins.
- **Homebrew is installed automatically** on Linux if not already present, into `$HOME/.homebrew`. No sudo is required. The installer aborts with a clear message if Homebrew installation fails.
- **Tool installation is faster.** Pre-built bottles replace Rust compilation. All tools previously installed via cargo (bat, eza, fd, rg, etc.) are now installed via brew.
- **Rust/cargo is still installed** unconditionally on all platforms and remains available for manual use. No cargo tools are uninstalled automatically.
- **`~/.zprofile` is no longer modified** by the installer. Homebrew activation is now in the version-controlled `zshrc`.

### Manifest (`manifest.toml`)

- `packages.linux_brew` lists Homebrew-compatible package names for the Linux no-sudo path. No `-dev` suffixes (Homebrew ships headers in the main formula). `xsel` is dropped (no Homebrew formula, X11-only). `zsh` is not in this list — it is managed via `brew.tools`. Candidate list: `autoconf`, `bison`, `curl`, `fontconfig`, `freetype`, `gawk`, `gcc`, `git`, `jp2a`, `libevent`, `make`, `ncurses`, `pkg-config`.

  > **gawk note:** The Homebrew bottle for gawk requires `HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew`. With a user-local prefix, it builds from source. The `make check` suite fails if the container has no UTF-8 locale. Fix: ensure `LC_ALL=en_US.UTF-8` is set in the build environment (Docker: install `locales` in bootstrap and configure `en_US.UTF-8`).

- `brew.tools` is the source of truth for user-facing CLI tools **and the user shell**, installed via brew on all platforms. Each entry has a `formula` (required), an optional `binary` override (when the installed binary name differs from the formula), and optional `flags`. Candidate list: `bat`, `dust`, `eza`, `fd`, `procs`, `ripgrep` (`binary = "rg"`), `starship`, `viu`, `zoxide`, `python@3.14` (`binary = "python3"`, `flags = "--force-bottle"`), `zsh`.

  > **zsh note:** The Homebrew zsh formula builds from source under a non-standard prefix and fails with a `boolcodes` redeclaration conflict between zsh's `termcap.c` and Homebrew's `ncursesw/term.h`. Fix strategy (in order): (A) install zsh before ncurses in the brew loop so the build uses system ncurses headers (requires `libncurses-dev` in the Docker bootstrap); (B) strip Homebrew include path via `CPATH`/`CFLAGS` during the zsh build; (C) `--force-bottle` with explicit FPATH configuration in `zshrc`.

- `python3` is removed from `packages.darwin` and `packages.linux` (now covered by `brew.tools`).
- `zsh` is removed from `packages.darwin` and `packages.linux` (now covered by `brew.tools`).
- `[cargo]` is retained as an empty-tools placeholder — cargo entries may be added in the future.

### Shell config (`zshrc`)

- PATH is built in reverse-priority order so each entry wins over what follows it.
- Homebrew is activated near the top of the file (replaces the runtime-written `~/.zprofile` entry).
- The new load order is: `cargo/env` → `nvm.sh` → `brew shellenv` → `.scripts` → `.local/bin`.

### Tests

- `check-brew-tools.sh` verifies each tool from `brew.tools` is reachable in PATH. Skips with a warning if `brew` is not found.
- `check-system-packages.sh` uses `NO_SUDO_INSTALL` env var (exported by `test.sh`) to select the check strategy: when set, uses `brew list` against `packages.linux_brew`; otherwise uses `dpkg -s` against `packages.linux`.
- `check-cargo-tools.sh` warns (does not fail) when `cargo` is not in PATH.
- `test.sh` exports `NO_SUDO_INSTALL=1` for the `no-sudo` target before running checks.
- `tests/docker/Dockerfile.no-sudo` bootstrap: `python3 curl git build-essential libncurses-dev locales` (no pre-installed apt packages beyond bootstrap). `locales` and `en_US.UTF-8` configuration enables gawk's make check to pass.

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Homebrew install fails | Installer aborts with a clear message |
| A single brew tool fails | Installation continues for remaining tools |
| `brew` not found (test) | `check-brew-tools.sh` warns and exits 0 |
| `NO_SUDO_INSTALL` set but `brew` not found (test) | `check-system-packages.sh` reports failure |
| `cargo` not in PATH (test) | `check-cargo-tools.sh` warns and exits 0 |

## Testing

- `test.sh sanity-check --docker sudo` — verifies apt path + brew tools.
- `test.sh sanity-check --docker no-sudo` — verifies Homebrew installation + brew tools (no apt).
- `check-brew-tools.sh` — verifies all brew tools are accessible via PATH.

