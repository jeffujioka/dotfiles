# Homebrew Delta: Cleanup, PATH Order, zsh & gawk — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the delta from the updated design spec: remove cargo cleanup logic, restore unconditional Rust install, move zsh to brew.tools (with ncurses build-order fix), add gawk back to linux_brew (with UTF-8 locale fix), and reorder PATH in zshrc.

**Architecture:** Five independent file changes plus Docker verification. `manifest.toml` drives `install.sh` and `test.sh`; `zshrc` is standalone; `Dockerfile.no-sudo` is test infrastructure. All changes are validated via `./test.sh sanity-check --docker all`.

**Tech Stack:** Bash, TOML (`manifest.toml`), Python 3.11+ (`read-manifest.py`), Docker (Ubuntu 24.04 test images).

**Testing note:** All verification uses Docker — `./test.sh sanity-check --docker <target>`. Build new images only when a Dockerfile changes.

---

## File Map

| Status | File | Responsibility |
|--------|------|----------------|
| Modify | `manifest.toml` | Remove `cargo_crate`; add `gawk` to `linux_brew`; add `zsh` to `brew.tools`; remove `zsh` from `linux` + `darwin` |
| Modify | `install.sh` | Remove `cleanup_cargo_tools()`; restore unconditional Rust install; add pre-zsh install on Linux before ncurses |
| Modify | `zshrc` | Reorder PATH blocks: cargo → nvm → brew → .scripts → .local/bin |
| Modify | `tests/docker/Dockerfile.no-sudo` | Add `libncurses-dev locales`; configure `en_US.UTF-8` for gawk test suite |

---

### Task 1: Update manifest.toml

**Files:**
- Modify: `manifest.toml`

- [ ] **Step 1: Remove `cargo_crate` from brew.tools; add zsh; remove zsh from linux/darwin; add gawk to linux_brew**

Replace the entire `[packages.linux]` through `[[brew.tools]] python@3.14` block:

```toml
[packages.linux]
# Installed via: sudo apt install
list = [
  "autoconf",
  "bison",
  "build-essential",
  "curl",
  "gawk",
  "gcc",
  "git",
  "jp2a",
  "libevent-dev",
  "libfontconfig1-dev",
  "libfreetype-dev",
  "libncurses-dev",
  "make",
  "pkg-config",
  "xsel",
]

[packages.darwin]
# Installed via: brew install
list = [
  "autoconf",
  "curl",
  "fontconfig",
  "freetype",
  "gawk",
  "gcc",
  "git",
  "jp2a",
  "libevent",
  "make",
  "ncurses",
  "pkg-config",
  "utf8proc",
]

[packages.linux_brew]
# Installed via: brew install (Linux, no-sudo path)
# gawk builds from source (non-standard prefix); requires LC_ALL=en_US.UTF-8
# for make check to pass. See Dockerfile.no-sudo for the locale setup.
# zsh is managed via brew.tools (installed before ncurses to avoid build conflict).
list = [
  "autoconf",
  "bison",
  "curl",
  "fontconfig",
  "freetype",
  "gawk",
  "gcc",
  "git",
  "jp2a",
  "libevent",
  "make",
  "ncurses",
  "pkg-config",
]

[cargo]
# Placeholder — add entries here for any future cargo tools.
# Rust/cargo is always installed; this list drives cargo install runs.
tools = []

[[brew.tools]]
formula = "bat"

[[brew.tools]]
formula = "dust"

[[brew.tools]]
formula = "eza"

[[brew.tools]]
formula = "fd"

[[brew.tools]]
formula = "procs"

[[brew.tools]]
formula = "ripgrep"
binary = "rg"

[[brew.tools]]
formula = "starship"

[[brew.tools]]
formula = "viu"

[[brew.tools]]
formula = "zoxide"

[[brew.tools]]
formula = "python@3.14"
binary = "python3"
flags = "--force-bottle"

[[brew.tools]]
formula = "zsh"
```

- [ ] **Step 2: Verify manifest parses correctly**

```bash
cd ~/.dotfiles
python3 helpers/read-manifest.py packages.linux.list
# Expected: no "zsh" in output

python3 helpers/read-manifest.py packages.darwin.list
# Expected: no "zsh" in output

python3 helpers/read-manifest.py packages.linux_brew.list
# Expected: gawk appears, no zsh

python3 helpers/read-manifest.py cargo.tools
# Expected: no output (empty list)

python3 helpers/read-manifest.py brew.tools --format tsv --fields "formula,binary:,flags:"
# Expected: 11 lines, last is "zsh\t\t"
# No cargo_crate column anywhere
```

- [ ] **Step 3: Commit**

```bash
cd ~/.dotfiles
git add manifest.toml
git commit -m "feat(manifest): remove cargo_crate, add zsh to brew.tools, gawk back to linux_brew"
```

---

### Task 2: Update install.sh

**Files:**
- Modify: `install.sh`

Changes:
1. Update manifest validation line (drop `cargo_crate:` field)
2. Remove `cleanup_cargo_tools()` function entirely
3. In `install_brew_tools()`: remove cleanup call + update warning message
4. Restore unconditional Rust installation in `install_dependencies()`
5. Add pre-zsh install on Linux (before `install_sys_packages`) to avoid ncurses header conflict

- [ ] **Step 1: Update manifest validation line**

Replace:
```bash
"$script_dir/helpers/read-manifest.py" brew.tools --format tsv --fields "formula,binary:,flags:,cargo_crate:" > /dev/null \
  || { echo "Error: manifest.toml is missing or invalid. Aborting."; exit 1; }
```

With:
```bash
"$script_dir/helpers/read-manifest.py" brew.tools --format tsv --fields "formula,binary:,flags:" > /dev/null \
  || { echo "Error: manifest.toml is missing or invalid. Aborting."; exit 1; }
```

- [ ] **Step 2: Remove `cleanup_cargo_tools()` and update `install_brew_tools()`**

Replace the entire `cleanup_cargo_tools()` function and `install_brew_tools()`:

```bash
install_brew_tools() {
  echo "Installing brew tools..."
  local failed_installs=0

  while IFS=$'\t' read -r formula binary flags; do
    binary="${binary:-$formula}"
    if command -v "$binary" &>/dev/null; then
      echo "'$binary' is already installed."
    else
      echo "Installing $formula via brew..."
      # shellcheck disable=SC2086
      brew install $flags "$formula" \
        || { echo "Warning: Failed to install $formula"; failed_installs=$((failed_installs + 1)); }
    fi
  done < <("$script_dir/helpers/read-manifest.py" brew.tools --format tsv \
              --fields "formula,binary:,flags:")

  if [ "$failed_installs" -gt 0 ]; then
    echo "Warning: $failed_installs brew tool(s) failed to install."
  fi
}
```

- [ ] **Step 3: Rewrite `install_dependencies()`**

Replace the entire `install_dependencies()` function:

```bash
install_dependencies() {
  # On Linux, install Homebrew and zsh BEFORE install_sys_packages.
  # zsh must be built before Homebrew's ncurses is installed — once
  # $HOME/.homebrew/include/ncursesw/ exists, zsh's source build hits a
  # boolcodes redeclaration conflict. Installing zsh first avoids this.
  if [[ "$OSTYPE" == linux* ]]; then
    install_linux_brew
    eval "$("$HOME/.homebrew/bin/brew" shellenv)"
    export SSL_CERT_FILE="${SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}"
    export CURL_CA_BUNDLE="${CURL_CA_BUNDLE:-/etc/ssl/certs/ca-certificates.crt}"
    if ! command -v zsh &>/dev/null; then
      echo "Pre-installing zsh (before ncurses to avoid header conflict)..."
      brew install zsh \
        || echo "Warning: zsh pre-install failed; will retry in brew tools pass"
    fi
  fi

  install_sys_packages

  if ! command -v cargo > /dev/null 2>&1 ; then
    echo "Installing Rust..."
    export RUSTUP_HOME=${XDG_CONFIG_HOME}/rustup
    export CARGO_HOME=${XDG_CONFIG_HOME}/cargo
    export TMPDIR=${XDG_CONFIG_HOME}/tmp
    mkdir -p "$TMPDIR"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

    source "${XDG_CONFIG_HOME}/cargo/env"

    rustup default stable
  fi

  rustup default stable

  install_brew_tools

  install_non_asdf_tools
}
```

- [ ] **Step 4: Check syntax**

```bash
cd ~/.dotfiles
bash -n install.sh && echo "Syntax OK"
# Expected: Syntax OK
```

- [ ] **Step 5: Commit**

```bash
cd ~/.dotfiles
git add install.sh
git commit -m "feat(install): remove cargo cleanup, restore Rust install, pre-install zsh before ncurses"
```

---

### Task 3: Reorder PATH in zshrc

**Files:**
- Modify: `zshrc`

**Current effective PATH priority (highest → lowest):** cargo > NVM > .scripts > .local/bin > Homebrew  
**Target:** .local/bin > .scripts > Homebrew > NVM > cargo

Since each `prepend` wins over what was prepended before it, the load order must be:
cargo first → NVM → brew shellenv → .scripts → .local/bin last.

Three edits are required:
1. Replace the current Homebrew + .local/bin + .scripts block with the full ordered PATH block
2. Remove the NVM lines (now moved into the new block)
3. Remove the cargo block (now moved into the new block)

- [ ] **Step 1: Replace the Homebrew/.local/bin/.scripts block with the full PATH block**

Replace:
```zsh
# Homebrew
if [[ "$OSTYPE" == darwin* ]] && [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ "$OSTYPE" == linux* ]] && [[ -x "$HOME/.homebrew/bin/brew" ]]; then
  eval "$($HOME/.homebrew/bin/brew shellenv)"
fi

if [[ ! "$PATH" == *${HOME}/.local/bin* ]]; then
  export PATH="$HOME/.local/bin:${PATH:+${PATH}:}"
fi
if [[ ! "$PATH" == *.scripts* ]]; then
  export PATH="$HOME/.scripts:${PATH:+${PATH}:}"
fi
```

With:
```zsh
# PATH priority (highest → lowest): .local/bin > .scripts > Homebrew > NVM > cargo
# Each block PREPENDs — the LAST one to run ends up at the FRONT of PATH.

# cargo — lowest priority (Rust toolchain, manual use)
CARGO_HOME="${XDG_CONFIG_HOME}/cargo"
CARGO_ENV="${CARGO_HOME}/env"
if [ -f "${CARGO_ENV}" ]; then
  source "${CARGO_ENV}"
elif [ -d "${CARGO_HOME}/bin" ]; then
  if [[ ! "$PATH" == *"${CARGO_HOME}/bin"* ]]; then
    export PATH="${CARGO_HOME}/bin:${PATH}"
  fi
fi

# NVM — above cargo
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Homebrew — above NVM
if [[ "$OSTYPE" == darwin* ]] && [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ "$OSTYPE" == linux* ]] && [[ -x "$HOME/.homebrew/bin/brew" ]]; then
  eval "$($HOME/.homebrew/bin/brew shellenv)"
fi

# .scripts — above Homebrew
if [[ ! "$PATH" == *.scripts* ]]; then
  export PATH="$HOME/.scripts:${PATH:+${PATH}:}"
fi

# .local/bin — highest priority
if [[ ! "$PATH" == *${HOME}/.local/bin* ]]; then
  export PATH="$HOME/.local/bin:${PATH:+${PATH}:}"
fi
```

- [ ] **Step 2: Remove the NVM block (now in new PATH section)**

Replace:
```zsh
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
```

With:
```zsh

```
(leave a blank line to preserve spacing)

- [ ] **Step 3: Remove the cargo block (now in new PATH section)**

Replace:
```zsh
# Setup cargo (required for all environments: docker, ubuntu, mac, vm, qemu, etc.)
# Source cargo/env if it exists, otherwise set CARGO_HOME and add to PATH
CARGO_HOME="${XDG_CONFIG_HOME}/cargo"
CARGO_ENV="${CARGO_HOME}/env"
if [ -f "${CARGO_ENV}" ]; then
  source "${CARGO_ENV}"
elif [ -d "${CARGO_HOME}/bin" ]; then
  # Fallback: add cargo/bin to PATH directly if env file doesn't exist
  if [[ ! "$PATH" == *"${CARGO_HOME}/bin"* ]]; then
    export PATH="${CARGO_HOME}/bin:${PATH}"
  fi
fi
```

With:
```zsh

```
(leave a blank line to preserve spacing)

- [ ] **Step 4: Verify PATH order with a quick sanity check**

```bash
# Check that the new block appears before NVM and cargo in the file
cd ~/.dotfiles
awk '/CARGO_HOME.*XDG_CONFIG_HOME.*cargo/{c=NR} /NVM_DIR/{n=NR} /opt.homebrew.bin.brew|.homebrew.bin.brew/{b=NR} /local.bin/{l=NR} END{print "cargo="c, "nvm="n, "brew="b, "local="l}' zshrc
# Expected: cargo=N nvm=M brew=P local=Q where N < M < P < Q
```

- [ ] **Step 5: Commit**

```bash
cd ~/.dotfiles
git add zshrc
git commit -m "feat(zshrc): reorder PATH — .local/bin > .scripts > brew > nvm > cargo"
```

---

### Task 4: Update Dockerfile.no-sudo

**Files:**
- Modify: `tests/docker/Dockerfile.no-sudo`

Changes:
- Add `libncurses-dev` (system ncurses headers for zsh source build)
- Add `locales` + configure `en_US.UTF-8` (for gawk's `make check` unicode tests)

- [ ] **Step 1: Replace bootstrap RUN block**

Replace:
```dockerfile
# Bootstrap: python3 to parse manifest, curl+git for Homebrew and asdf,
# build-essential because Homebrew on Linux requires a C compiler for
# source builds when bottles are unavailable.
RUN apt-get update && apt-get install -y python3 curl git build-essential \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
```

With:
```dockerfile
# Bootstrap: python3 to parse manifest, curl+git for Homebrew and asdf.
# build-essential: C compiler for Homebrew source builds.
# libncurses-dev: system ncurses headers; zsh must build against these
#   (not Homebrew's) to avoid a boolcodes redeclaration conflict.
# locales + en_US.UTF-8: gawk's make check validates unicode escape
#   sequences and fails silently without a UTF-8 locale.
RUN apt-get update \
    && apt-get install -y python3 curl git build-essential libncurses-dev locales \
    && locale-gen en_US.UTF-8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
```

- [ ] **Step 2: Rebuild the no-sudo image**

```bash
cd ~/.dotfiles
./test.sh build-image no-sudo 2>&1 | tail -10
# Expected: image builds successfully, last line contains "naming to ... dotfiles-test-no-sudo"
```

- [ ] **Step 3: Commit**

```bash
cd ~/.dotfiles
git add tests/docker/Dockerfile.no-sudo
git commit -m "test(docker): add libncurses-dev + en_US.UTF-8 locale for zsh build and gawk make check"
```

---

### Task 5: Verify sudo scenario GREEN

- [ ] **Step 1: Run sudo docker test**

```bash
cd ~/.dotfiles
./test.sh sanity-check --docker sudo 2>&1 | tee /tmp/sudo-delta.log | \
  rg "✗|✓|⚠|Results:|==="
```

Expected results section:
```
  Results: N passed, 1 failed, 1 warnings
```
- The 1 failure is `asdf not found` — pre-existing, unrelated to this change.
- The 1 warning is `cargo not found in PATH — skipping cargo tools check` — expected; Rust install is triggered by `cargo.tools` being empty (actually, wait — Rust IS now installed unconditionally; cargo should be in PATH after install). If cargo is found, warnings = 0.

> If sudo shows failures beyond asdf, stop and investigate before proceeding to no-sudo.

- [ ] **Step 2: Confirm zsh is present in brew tools output**

```bash
rg "zsh" /tmp/sudo-delta.log | rg "✓|✗"
# Expected: ✓ zsh (zsh 5.x.x)
```

---

### Task 6: Verify no-sudo scenario GREEN

- [ ] **Step 1: Run no-sudo docker test**

```bash
cd ~/.dotfiles
./test.sh sanity-check --docker no-sudo 2>&1 | tee /tmp/nosudo-delta.log | \
  rg "✗|✓|⚠|Results:|==="
```

Expected:
```
=== System Packages ===
  ✓ autoconf installed
  ✓ bison installed
  ...
  ✓ gawk installed
  ...
=== Brew Tools ===
  ✓ bat (bat 0.x.x)
  ...
  ✓ zsh (zsh 5.x.x)
  ...
  Results: N passed, 1 failed, 0 warnings
```
- 1 failure: `asdf not found` (pre-existing).
- gawk ✓ (UTF-8 locale fix allows make check to pass).
- zsh ✓ in brew tools (pre-install before ncurses avoids build conflict).

- [ ] **Step 2: Confirm gawk and zsh specifically**

```bash
rg "gawk|zsh" /tmp/nosudo-delta.log | rg "✓|✗"
# Expected:
#   ✓ gawk installed
#   ✓ zsh (zsh 5.x.x)
```

---

### Task 7: Final gate — both scenarios

- [ ] **Step 1: Run both**

```bash
cd ~/.dotfiles
./test.sh sanity-check --docker all 2>&1 | rg "🐳|Results:"
```

Expected:
```
🐳 [sudo] Running in Docker...
  Results: N passed, 1 failed, 0 warnings
🐳 [no-sudo] Running in Docker...
  Results: M passed, 1 failed, 0 warnings
```

Both 1 failure = `asdf not found` (pre-existing).

- [ ] **Step 2: Final commit if any loose changes remain**

```bash
cd ~/.dotfiles
git status --short
# Expected: nothing (all changes committed in Tasks 1-4)
# If anything is unstaged:
git add -A
git commit -m "chore: ensure all delta changes committed"
```
