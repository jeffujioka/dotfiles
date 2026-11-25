#!/bin/bash
# Standalone test for install.sh glob handling: strip_ext, platform filter,
# collision refusal, strip_ext-on-non-glob refusal. Runs entirely in a
# sandbox: fixture manifest (absolute sources), sandboxed $HOME.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
pass() {
  PASS=$((PASS + 1))
  echo "  ok: $1"
}
fail() {
  FAIL=$((FAIL + 1))
  echo "  FAIL: $1"
}

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/src/scripts" "$SANDBOX/home"
printf '#!/bin/sh\necho foo\n' >"$SANDBOX/src/scripts/foo.sh"
printf '#!/usr/bin/env python3\n' >"$SANDBOX/src/scripts/bar.py"
printf '#!/bin/sh\necho baz\n' >"$SANDBOX/src/scripts/baz"

write_manifest() { # write_manifest EXTRA_TOML
  cat >"$SANDBOX/manifest.toml" <<EOF
[brew]
tools = []

[[symlinks]]
source = "$SANDBOX/src/scripts/*"
target = "~/.local/sbin/*"
type = "glob"
strip_ext = true

[[symlinks]]
source = "$SANDBOX/src/scripts/*"
target = "~/.local/other/*"
type = "glob"
platform = "linux"
$1
EOF
}

run_install() {
  HOME="$SANDBOX/home" DOTFILES_MANIFEST="$SANDBOX/manifest.toml" \
    WD40_PLATFORM="${1:-darwin}" \
    "$REPO_ROOT/install.sh" --no-install-deps >/dev/null 2>&1
}

# --- happy path: strip + platform filter (darwin) ---
write_manifest ""
if run_install darwin; then pass "install exits 0"; else fail "install exited nonzero"; fi
if [ -L "$SANDBOX/home/.local/sbin/foo" ]; then pass "foo.sh → foo"; else fail "foo.sh not stripped"; fi
if [ -L "$SANDBOX/home/.local/sbin/bar" ]; then pass "bar.py → bar"; else fail "bar.py not stripped"; fi
if [ -L "$SANDBOX/home/.local/sbin/baz" ]; then pass "baz unchanged"; else fail "baz missing"; fi
if [ ! -e "$SANDBOX/home/.local/sbin/foo.sh" ]; then pass "no unstripped foo.sh"; else fail "unstripped foo.sh linked"; fi
if [ ! -d "$SANDBOX/home/.local/other" ]; then pass "linux entry skipped on darwin"; else fail "platform filter leaked"; fi

# links resolve to the fixture sources
resolved=$(readlink "$SANDBOX/home/.local/sbin/foo")
case "$resolved" in
  */src/scripts/foo.sh) pass "foo resolves to source" ;;
  *) fail "foo resolves to '$resolved'" ;;
esac

# --- platform filter (linux) installs the second entry ---
rm -rf "${SANDBOX:?}/home"
mkdir -p "$SANDBOX/home"
if run_install linux; then pass "linux install exits 0"; else fail "linux install failed"; fi
if [ -L "$SANDBOX/home/.local/other/foo.sh" ]; then pass "linux entry installed unstripped"; else fail "linux entry missing"; fi

# --- collision refusal: foo.sh and foo.py strip to one name ---
printf '#!/usr/bin/env python3\n' >"$SANDBOX/src/scripts/foo.py"
rm -rf "${SANDBOX:?}/home"
mkdir -p "$SANDBOX/home"
if run_install darwin; then fail "collision NOT refused"; else pass "collision refused (nonzero exit)"; fi
rm "$SANDBOX/src/scripts/foo.py"

# --- strip_ext on a non-glob entry is refused ---
write_manifest '
[[symlinks]]
source = "'"$SANDBOX"'/src/scripts/foo.sh"
target = "~/.local/one-file"
strip_ext = true
'
rm -rf "${SANDBOX:?}/home"
mkdir -p "$SANDBOX/home"
if run_install darwin; then fail "strip_ext on symlink NOT refused"; else pass "strip_ext on symlink refused"; fi

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
