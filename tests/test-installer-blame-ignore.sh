#!/bin/bash
# Standalone test for install.sh's blame step: the installer sets
# blame.ignoreRevsFile in the local git config of the clone it lives in (never
# the cwd's repo, never the global config). Runs in a sandbox: fixture clone,
# sandboxed $HOME, fixture manifest — same approach as
# tests/test-installer-home-source.sh. Keeps its own PASS/FAIL tally.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=helpers.sh
. "$SCRIPT_DIR/helpers.sh"

section "Installer: blame.ignoreRevsFile in the clone's local git config"

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

CLONE="$SANDBOX/clone"
OTHER="$SANDBOX/other"
HOME_DIR="$SANDBOX/home"
mkdir -p "$CLONE" "$OTHER" "$HOME_DIR"
cp "$REPO_ROOT/install.sh" "$CLONE/"
cp -R "$REPO_ROOT/helpers" "$CLONE/helpers"
printf '# fixture\n' >"$CLONE/.git-blame-ignore-revs"
printf '[brew]\ntools = []\n' >"$SANDBOX/manifest.toml"
git init -q "$CLONE"
git init -q "$OTHER"

# run_install — run the clone's installer from an unrelated repo (the cwd).
run_install() {
  (cd "$OTHER" && HOME="$HOME_DIR" GIT_CONFIG_GLOBAL="$HOME_DIR/.gitconfig" \
    DOTFILES_MANIFEST="$SANDBOX/manifest.toml" \
    "$CLONE/install.sh" --no-install-deps >"$SANDBOX/out" 2>&1)
}

if run_install; then
  t_pass "installer runs in the fixture clone"
else
  t_fail "installer runs in the fixture clone"
  sed 's/^/    /' "$SANDBOX/out"
fi

check_setting() {
  [ "$(git -C "$CLONE" config --local --get blame.ignoreRevsFile)" = ".git-blame-ignore-revs" ] \
    && ! git -C "$OTHER" config --local --get blame.ignoreRevsFile >/dev/null \
    && ! GIT_CONFIG_GLOBAL="$HOME_DIR/.gitconfig" git config --global --get blame.ignoreRevsFile >/dev/null
}
if check_setting; then
  t_pass "installer sets blame.ignoreRevsFile in the clone only"
else
  t_fail "installer sets blame.ignoreRevsFile in the clone only"
fi

# Idempotent: a second run leaves exactly one value.
if run_install && [ "$(git -C "$CLONE" config --local --get-all blame.ignoreRevsFile | wc -l | tr -d ' ')" = "1" ]; then
  t_pass "second run keeps a single setting"
else
  t_fail "second run keeps a single setting"
fi

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
