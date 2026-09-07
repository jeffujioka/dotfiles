#!/bin/bash
# Standalone test for install.sh `seed` symlink-type handling: create-if-
# absent, never-overwrite, and backup=true refusal. This is the regression
# test promised by docs/superpowers/specs/2026-09-07-gitconfig-layering-design.md
# ("Tests" section) for the bug that motivated that spec: `type = "copy"`
# silently reverted a machine-local ~/.gitconfig on every install. Runs
# entirely in a sandbox: fixture manifest (absolute sources), sandboxed
# $HOME — same approach as tests/test-installer-glob.sh.
#
# Wired into test.sh's sanity-check (run_local_checks): sources helpers.sh
# so each assertion also bumps the shared SANITY_COUNTERS_FILE, the same
# mechanism tests/check-symlinks.sh uses. A local PASS/FAIL tally (mirroring
# test-installer-glob.sh) is kept separately so this script's own exit code
# reflects only its own assertions, not whatever else has already run in the
# shared counters file when invoked from within test.sh.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=helpers.sh
. "$SCRIPT_DIR/helpers.sh"

section "Installer: seed type (create-if-absent / never-overwrite / backup refusal)"

PASS=0; FAIL=0
seed_pass() { PASS=$((PASS+1)); pass "$1"; }
seed_fail() { FAIL=$((FAIL+1)); fail "$1"; }

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/src" "$SANDBOX/home"

SEED_SOURCE="$SANDBOX/src/seed-file.seed"
printf 'seed source content — %s\n' "$$" > "$SEED_SOURCE"

EXISTING_SNAPSHOT="$SANDBOX/existing-snapshot"
printf 'PRE-EXISTING machine-local content — must survive\n' > "$EXISTING_SNAPSHOT"

# write_manifest TARGET_NAME BACKUP_LINE
# BACKUP_LINE is "backup = true", "backup = false", or "" to omit the field
# entirely (exercising install.sh's documented default of backup:true).
write_manifest() {
  cat > "$SANDBOX/manifest.toml" <<EOF
[brew]
tools = []

[[symlinks]]
source = "$SEED_SOURCE"
target = "~/$1"
type = "seed"
$2
EOF
}

# run_install PLATFORM — combined stdout+stderr captured to $SANDBOX/out
run_install() {
  HOME="$SANDBOX/home" DOTFILES_MANIFEST="$SANDBOX/manifest.toml" \
    WD40_PLATFORM="${1:-darwin}" \
    "$REPO_ROOT/install.sh" --no-install-deps > "$SANDBOX/out" 2>&1
}

reset_home() { rm -rf "$SANDBOX/home"; mkdir -p "$SANDBOX/home"; }

# --- Case 1: create-if-absent ---
write_manifest "seed-absent" "backup = false"
reset_home
if run_install darwin
then seed_pass "install exits 0 (target absent)"
else seed_fail "install exited nonzero (target absent): $(cat "$SANDBOX/out")"
fi
if [ -e "$SANDBOX/home/seed-absent" ]; then
  if cmp -s "$SANDBOX/home/seed-absent" "$SEED_SOURCE"; then
    seed_pass "seed creates absent target, content matches source"
  else
    seed_fail "seed created absent target but content differs from source"
  fi
else
  seed_fail "seed did not create the absent target"
fi

# --- Case 2: never-overwrite (the regression test for the bug that
# motivated the spec: type = "copy" used to silently revert a live
# ~/.gitconfig on every install) ---
write_manifest "seed-existing" "backup = false"
reset_home
cp "$EXISTING_SNAPSHOT" "$SANDBOX/home/seed-existing"
if run_install darwin
then seed_pass "install exits 0 (target pre-existing)"
else seed_fail "install exited nonzero (target pre-existing): $(cat "$SANDBOX/out")"
fi
if [ -e "$SANDBOX/home/seed-existing" ]; then
  if cmp -s "$SANDBOX/home/seed-existing" "$EXISTING_SNAPSHOT"; then
    seed_pass "seed never overwrites an existing target (byte-for-byte unchanged)"
  else
    seed_fail "seed OVERWROTE the existing target — regression reintroduced"
  fi
  if cmp -s "$SANDBOX/home/seed-existing" "$SEED_SOURCE"; then
    seed_fail "existing target now matches seed source — regression reintroduced"
  else
    seed_pass "existing target still differs from seed source, as expected"
  fi
else
  seed_fail "existing target vanished entirely — worse than the original regression"
fi

# --- Case 3: backup=true (explicit) is refused, per install.sh:288-294 ---
write_manifest "seed-refused-explicit" "backup = true"
reset_home
if run_install darwin
then seed_fail "backup=true seed NOT refused (explicit)"
else seed_pass "backup=true seed refused (explicit, nonzero exit)"
fi
if grep -qF "Error: seed entries never back up (source: $SEED_SOURCE)" "$SANDBOX/out"; then
  seed_pass "refusal error message matches install.sh (explicit backup=true)"
else
  seed_fail "refusal error message mismatch (explicit): $(cat "$SANDBOX/out")"
fi
if [ ! -e "$SANDBOX/home/seed-refused-explicit" ]; then
  seed_pass "refused seed did not create the target (explicit backup=true)"
else
  seed_fail "refused seed created the target anyway (explicit backup=true)"
fi

# --- Case 3b: backup left at its documented default (field omitted) is
# refused identically. Spec: "Since backup defaults to true, seed entries
# must set backup = false explicitly." ---
write_manifest "seed-refused-default" ""
reset_home
if run_install darwin
then seed_fail "default-backup seed NOT refused"
else seed_pass "default-backup seed refused (nonzero exit)"
fi
if [ ! -e "$SANDBOX/home/seed-refused-default" ]; then
  seed_pass "refused seed did not create the target (default backup)"
else
  seed_fail "refused seed created the target anyway (default backup)"
fi

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
