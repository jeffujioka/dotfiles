#!/bin/bash
# Standalone test for install.sh `~/` symlink sources: a manifest `source`
# starting with `~/` names a path under $HOME (not a repo file), and the link
# to it is made VERBATIM — never resolved through to the repo — so one entry
# can alias another entry's installed link (macOS: ~/Library/Application
# Support/biome -> ~/.config/biome -> <repo>/config/biome). Runs entirely in a
# sandbox: fixture manifest, sandboxed $HOME — same approach as
# tests/test-installer-seed.sh. Wired into test.sh's sanity-check; keeps its
# own PASS/FAIL tally so its exit code reflects only its own assertions.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=helpers.sh
. "$SCRIPT_DIR/helpers.sh"

section "Installer: ~/ link sources (verbatim alias / missing-source refusal)"

PASS=0
FAIL=0
t_pass() {
  PASS=$((PASS + 1))
  pass "$1"
}
t_fail() {
  FAIL=$((FAIL + 1))
  fail "$1"
}

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/src/biome" "$SANDBOX/home"
printf '{ "marker": "%s" }\n' "$$" >"$SANDBOX/src/biome/biome.jsonc"

# shellcheck disable=SC2088  # literal manifest text; install.sh expands the ~
CANONICAL='~/.config/biome'
# shellcheck disable=SC2088
ALIAS='~/Library/Application Support/biome'

# write_manifest WITH_CANONICAL — the canonical entry (repo dir -> ~/.config)
# is omitted when WITH_CANONICAL is "no", leaving the alias with no source.
write_manifest() {
  {
    printf '[brew]\ntools = []\n'
    if [ "$1" != "no" ]; then
      printf '\n[[symlinks]]\nsource = "%s/src/biome"\ntarget = "%s"\n' "$SANDBOX" "$CANONICAL"
    fi
    printf '\n[[symlinks]]\nsource = "%s"\ntarget = "%s"\nplatform = "darwin"\n' "$CANONICAL" "$ALIAS"
  } >"$SANDBOX/manifest.toml"
}

# run_install PLATFORM — combined stdout+stderr captured to $SANDBOX/out
run_install() {
  HOME="$SANDBOX/home" DOTFILES_MANIFEST="$SANDBOX/manifest.toml" \
    WD40_PLATFORM="${1:-darwin}" \
    "$REPO_ROOT/install.sh" --no-install-deps >"$SANDBOX/out" 2>&1
}

reset_home() {
  rm -rf "$SANDBOX/home"
  mkdir -p "$SANDBOX/home"
}

HOME_DIR="$SANDBOX/home"
ALIAS_PATH="$HOME_DIR/Library/Application Support/biome"
CANON_PATH="$HOME_DIR/.config/biome"

# --- Case 1: darwin — alias points at the ~/.config link itself ---
write_manifest yes
reset_home
if run_install darwin; then
  t_pass "darwin install exits 0"
else
  t_fail "darwin install exited nonzero: $(tail -3 "$SANDBOX/out")"
fi
if [ -L "$ALIAS_PATH" ] && [ "$(readlink "$ALIAS_PATH")" = "$CANON_PATH" ]; then
  t_pass "alias is a verbatim link to ~/.config/biome"
else
  t_fail "alias → '$(readlink "$ALIAS_PATH" 2>/dev/null)' (expected $CANON_PATH)"
fi
if grep -q "\"marker\": \"$$\"" "$ALIAS_PATH/biome.jsonc" 2>/dev/null; then
  t_pass "repo file readable through the alias"
else
  t_fail "repo file not readable through $ALIAS_PATH"
fi

# --- Case 2: second run is idempotent (re-linking a dir symlink) ---
if run_install darwin && [ "$(readlink "$ALIAS_PATH")" = "$CANON_PATH" ] \
  && [ ! -L "$SANDBOX/src/biome/biome" ]; then
  t_pass "re-run keeps the alias and creates no nested link"
else
  t_fail "re-run broke the alias or nested a link: $(tail -3 "$SANDBOX/out")"
fi

# --- Case 3: linux — alias entry is darwin-only, canonical link remains ---
reset_home
if run_install linux; then
  t_pass "linux install exits 0"
else
  t_fail "linux install exited nonzero: $(tail -3 "$SANDBOX/out")"
fi
if [ -L "$CANON_PATH" ] && [ ! -e "$HOME_DIR/Library" ]; then
  t_pass "linux gets ~/.config/biome only (no Library/Application Support)"
else
  t_fail "linux install created the macOS alias or missed ~/.config/biome"
fi

# --- Case 4: missing ~/ source is refused, not left dangling ---
write_manifest no
reset_home
if run_install darwin; then
  t_fail "missing ~/ source NOT refused"
else
  t_pass "missing ~/ source refused (nonzero exit)"
fi
if grep -qE '^Error: .*does not exist' "$SANDBOX/out"; then
  t_pass "refusal names the missing source"
else
  t_fail "refusal message lacks 'does not exist': $(tail -3 "$SANDBOX/out")"
fi
if [ ! -L "$ALIAS_PATH" ]; then
  t_pass "no dangling alias created"
else
  t_fail "dangling alias left at $ALIAS_PATH"
fi

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
