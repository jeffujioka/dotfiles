#!/bin/bash
# Standalone test for install.sh `script-install` resources
# (install_script_installers): creates-skip, platform filter, shell/args/env/
# post_install plumbing, sha256 pinning, and required-vs-warn failure. Runs in
# a sandbox with a fixture manifest and a fake `curl` on PATH, so nothing
# touches the network — same approach as tests/test-installer-seed.sh.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=helpers.sh
. "$SCRIPT_DIR/helpers.sh"

section "Installer: script-install (creates / platform / sha256 / required)"

PASS=0; FAIL=0
t_pass() { PASS=$((PASS+1)); pass "$1"; }
t_fail() { FAIL=$((FAIL+1)); fail "$1"; }

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/bin" "$SANDBOX/home"

# Fixture "vendor script": records its args and the exported env var.
cat > "$SANDBOX/vendor.sh" <<'VENDOR'
echo "ran args=[$*] foo=[${FOO:-}]" >> "$HOME/script-ran"
VENDOR
VENDOR_SHA=$(file_sha256 "$SANDBOX/vendor.sh")

# Fake curl: copy the fixture to the -o target, ignore everything else.
cat > "$SANDBOX/bin/curl" <<CURL
#!/bin/bash
while [ \$# -gt 0 ]; do
  if [ "\$1" = "-o" ]; then cp "$SANDBOX/vendor.sh" "\$2"; exit 0; fi
  shift
done
exit 1
CURL
chmod +x "$SANDBOX/bin/curl"

# Stub binary that makes `creates` already satisfied.
printf '#!/bin/sh\n' > "$SANDBOX/bin/present-tool"; chmod +x "$SANDBOX/bin/present-tool"

# run_fn MANIFEST_BODY PLATFORM — runs install_script_installers from
# install.sh in a subshell; combined output in $SANDBOX/out.
run_fn() {
  printf '%s\n' "$1" > "$SANDBOX/manifest.toml"
  (
    export HOME="$SANDBOX/home" DOTFILES_MANIFEST="$SANDBOX/manifest.toml" \
           WD40_PLATFORM="${2:-linux}" PATH="$SANDBOX/bin:$PATH"
    script_dir="$REPO_ROOT"
    . "$REPO_ROOT/helpers/shell-utils.sh"
    # shellcheck disable=SC1090
    . <(sed -n '/^read_manifest()/,/^}/p;/^run_script_install()/,/^)/p;/^install_script_installers()/,/^}/p' "$REPO_ROOT/install.sh")
    install_script_installers
  ) > "$SANDBOX/out" 2>&1
}
reset_home() { rm -rf "$SANDBOX/home"; mkdir -p "$SANDBOX/home"; }

entry() { # name creates extra-lines...
  printf '[[resources]]\nname = "%s"\ntype = "script-install"\nurl = "https://example.invalid/i"\ncreates = "%s"\n' "$1" "$2"
  shift 2; printf '%s\n' "$@"
}

# --- Case 1: runs script; shell default, args, env, post_install plumbed
# through even with empty optional fields in between (tab-collapse regression).
reset_home
if run_fn "$(entry thing absent-tool-1 'args = "-y --flag"' 'env = "FOO=bar"' 'post_install = "touch $HOME/post-ran"')"; then
  t_pass "install exits 0"
else
  t_fail "install exited nonzero: $(cat "$SANDBOX/out")"
fi
if [ "$(cat "$SANDBOX/home/script-ran" 2>/dev/null)" = "ran args=[-y --flag] foo=[bar]" ]; then
  t_pass "script ran with args and env"
else
  t_fail "script args/env wrong: $(cat "$SANDBOX/home/script-ran" 2>/dev/null)"
fi
[ -e "$SANDBOX/home/post-ran" ] && t_pass "post_install ran" || t_fail "post_install did not run"

# --- Case 2: creates already on PATH → skipped
reset_home
run_fn "$(entry thing present-tool)"
[ ! -e "$SANDBOX/home/script-ran" ] && t_pass "skipped when creates is on PATH" || t_fail "ran despite creates present"

# --- Case 3: platform mismatch → skipped; match → runs
reset_home
run_fn "$(entry thing absent-tool-3 'platform = "darwin"')" linux
[ ! -e "$SANDBOX/home/script-ran" ] && t_pass "skipped on platform mismatch" || t_fail "ran on wrong platform"
run_fn "$(entry thing absent-tool-3 'platform = "linux"')" linux
[ -e "$SANDBOX/home/script-ran" ] && t_pass "runs on matching platform" || t_fail "did not run on matching platform"

# --- Case 4: sha256 pin — match runs; mismatch warns and does not run
reset_home
run_fn "$(entry thing absent-tool-4 "sha256 = \"$VENDOR_SHA\"")"
[ -e "$SANDBOX/home/script-ran" ] && t_pass "matching sha256 runs" || t_fail "matching sha256 did not run"
reset_home
if run_fn "$(entry thing absent-tool-4 'sha256 = "deadbeef"')"; then
  t_pass "non-required sha mismatch does not abort (exit 0)"
else
  t_fail "non-required sha mismatch aborted"
fi
[ ! -e "$SANDBOX/home/script-ran" ] && t_pass "sha mismatch: script not run" || t_fail "script ran despite sha mismatch"
grep -q "Warning: Failed to install thing" "$SANDBOX/out" && t_pass "sha mismatch warns" || t_fail "no warning on sha mismatch"

# --- Case 5: required failure aborts nonzero
reset_home
if run_fn "$(entry thing absent-tool-5 'sha256 = "deadbeef"' 'required = true')"; then
  t_fail "required failure did not abort"
else
  t_pass "required failure aborts (nonzero exit)"
fi

# --- Case 6: manifest bug (no creates) is refused
reset_home
printf '[[resources]]\nname = "bad"\ntype = "script-install"\nurl = "https://example.invalid/i"\n' > "$SANDBOX/bad.toml"
if run_fn "$(cat "$SANDBOX/bad.toml")"; then
  t_fail "missing creates not refused"
else
  t_pass "missing creates refused"
fi

# --- Case 7: non-default shell is the interpreter
reset_home
printf '#!/bin/bash\necho used > "$HOME/shell-used"\nexec bash "$@"\n' > "$SANDBOX/bin/mysh"; chmod +x "$SANDBOX/bin/mysh"
run_fn "$(entry thing absent-tool-7 'shell = "mysh"')"
[ -e "$SANDBOX/home/shell-used" ] && [ -e "$SANDBOX/home/script-ran" ] \
  && t_pass "configured shell runs the script" || t_fail "configured shell not used"

# --- Case 8: brew.tools platform filter (empty binary + platform must not shift
# fields; unfiltered and matching entries install, mismatching is skipped)
printf '#!/bin/bash\n[ "$1" = install ] && echo "$*" >> "$HOME/brew-installed"\nexit 0\n' > "$SANDBOX/bin/brew"; chmod +x "$SANDBOX/bin/brew"
run_brew() {
  printf '%s\n' "$1" > "$SANDBOX/manifest.toml"
  (
    export HOME="$SANDBOX/home" DOTFILES_MANIFEST="$SANDBOX/manifest.toml" \
           WD40_PLATFORM=linux PATH="$SANDBOX/bin:$PATH"
    script_dir="$REPO_ROOT"
    . "$REPO_ROOT/helpers/shell-utils.sh"
    # shellcheck disable=SC1090
    . <(sed -n '/^read_manifest()/,/^}/p;/^install_brew_tools()/,/^}/p' "$REPO_ROOT/install.sh")
    install_brew_tools
  ) > "$SANDBOX/out" 2>&1
}
reset_home
run_brew '[[brew.tools]]
formula = "everywhere-pkg"

[[brew.tools]]
formula = "linux-pkg"
platform = "linux"

[[brew.tools]]
formula = "darwin-pkg"
platform = "darwin"

[[brew.tools]]
formula = "darwin-flagged"
flags = "--cask"
platform = "darwin"'
installed=$(cat "$SANDBOX/home/brew-installed" 2>/dev/null)
if [ "$installed" = "$(printf 'install everywhere-pkg\ninstall linux-pkg')" ]; then
  t_pass "brew platform filter installs only matching entries"
else
  t_fail "brew platform filter wrong: $installed"
fi

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
