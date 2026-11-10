#!/bin/bash
# Standalone test for wd40/common/scripts/asdf-update.sh: bumps ~/.tool-versions
# to the newest installed version, never writes a version whose install failed,
# skips plugins without a latest version, and --weekly throttles repeat runs.
# Sandboxed $HOME with a fake asdf.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=helpers.sh
. "$SCRIPT_DIR/helpers.sh"

section "asdf-update: global tool versions"

PASS=0; FAIL=0
t_pass() { PASS=$((PASS+1)); pass "$1"; }
t_fail() { FAIL=$((FAIL+1)); fail "$1"; }
check() { if eval "$2"; then t_pass "$1"; else t_fail "$1"; fi; }

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/home" "$SANDBOX/bin"

# Fake asdf. LATEST_<plugin> is the newest version ("" = no latest callback);
# FAIL_INSTALL names a plugin whose install fails. `set --home` rewrites
# $HOME/.tool-versions like the real command.
cat > "$SANDBOX/bin/asdf" <<'EOT'
#!/bin/bash
case "$1" in
  plugin) printf '%s\n' nodejs golang ;;
  latest)
    case "$2" in
      nodejs) v="${LATEST_NODEJS:-}" ;;
      golang) v="${LATEST_GOLANG:-}" ;;
    esac
    [ -n "$v" ] && echo "$v" || exit 1 ;;
  install)
    [ "${FAIL_INSTALL:-}" = "$2" ] && exit 1
    echo "install $2 $3" >> "$ASDF_LOG" ;;
  set)
    shift; [ "$1" = "--home" ] && shift
    f="$HOME/.tool-versions"; touch "$f"
    grep -v "^$1 " "$f" > "$f.new"; echo "$1 $2" >> "$f.new"; mv "$f.new" "$f" ;;
esac
EOT
chmod +x "$SANDBOX/bin/asdf"

export ASDF_LOG="$SANDBOX/asdf.log"
run() { HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$PATH" "$REPO_ROOT/wd40/common/scripts/asdf-update.sh" "$@" >"$SANDBOX/out" 2>&1; }
tv() { awk -v p="$1" '$1 == p { print $2 }' "$SANDBOX/home/.tool-versions"; }
stamp="$SANDBOX/home/.local/state/dotfiles/asdf-update.stamp"

printf 'nodejs 26.10.0\ngolang 1.20.0\n' > "$SANDBOX/home/.tool-versions"

LATEST_NODEJS=26.13.0 LATEST_GOLANG="" run
check "newer latest is written to ~/.tool-versions" '[ "$(tv nodejs)" = 26.13.0 ]'
check "plugin without a latest version is left as it was" '[ "$(tv golang)" = 1.20.0 ]'
check "plugin without a latest version does not fail the run" 'grep -q "no latest version" "$SANDBOX/out"'
check "a successful run leaves the stamp" '[ -f "$stamp" ]'

rm -f "$stamp"; : > "$ASDF_LOG"
FAIL_INSTALL=nodejs LATEST_NODEJS=27.0.0 LATEST_GOLANG="" run
rc=$?
check "failed install leaves ~/.tool-versions on the installed version" '[ "$(tv nodejs)" = 26.13.0 ]'
check "failed install exits non-zero" '[ "$rc" -ne 0 ]'
check "failed install leaves no stamp, so --weekly retries" '[ ! -f "$stamp" ]'

LATEST_NODEJS=26.13.0 LATEST_GOLANG="" run --weekly
: > "$ASDF_LOG"
LATEST_NODEJS=27.0.0 LATEST_GOLANG="" run --weekly
check "--weekly does nothing within a week of a good run" '[ ! -s "$ASDF_LOG" ] && [ "$(tv nodejs)" = 26.13.0 ]'

touch -d '8 days ago' "$stamp"
LATEST_NODEJS=27.0.0 LATEST_GOLANG="" run --weekly
check "--weekly runs again after a week" '[ "$(tv nodejs)" = 27.0.0 ]'

LATEST_NODEJS=28.0.0 LATEST_GOLANG="" run
check "without --weekly it always runs" '[ "$(tv nodejs)" = 28.0.0 ]'

[ "$FAIL" -eq 0 ]
