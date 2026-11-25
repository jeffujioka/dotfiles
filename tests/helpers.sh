#!/bin/bash
# Shared TAP-like output functions for sanity check scripts.
# Sourced by each check-*.sh and by test.sh.

_GREEN='\033[0;32m'
_RED='\033[0;31m'
_YELLOW='\033[0;33m'
_BOLD='\033[1m'
_NC='\033[0m'

# Counters file — shared across sub-scripts via environment variable.
# Each sub-script sources this file and reads/writes the same counters file,
# so the orchestrator (test.sh) sees aggregated totals.
SANITY_COUNTERS_FILE="${SANITY_COUNTERS_FILE:-$(mktemp)}"
export SANITY_COUNTERS_FILE

if [ ! -s "$SANITY_COUNTERS_FILE" ]; then
  printf '0 0 0' >"$SANITY_COUNTERS_FILE"
fi

_update_counter() {
  # NOTE: Non-atomic read-modify-write — check scripts must run sequentially.
  # Parallelising them (e.g. with &) would corrupt counter state.
  local field="$1" # 1=pass, 2=fail, 3=warn
  local counters
  counters=$(cat "$SANITY_COUNTERS_FILE")
  local p f w
  read -r p f w <<<"$counters"
  case "$field" in
    1) p=$((p + 1)) ;;
    2) f=$((f + 1)) ;;
    3) w=$((w + 1)) ;;
  esac
  printf '%d %d %d' "$p" "$f" "$w" >"$SANITY_COUNTERS_FILE"
}

pass() {
  _update_counter 1
  printf "  ${_GREEN}✓${_NC} %s\n" "$1"
}

fail() {
  _update_counter 2
  printf "  ${_RED}✗${_NC} %s\n" "$1"
}

warn() {
  _update_counter 3
  printf "  ${_YELLOW}⚠${_NC} %s\n" "$1"
}

section() {
  printf "\n${_BOLD}=== %s ===${_NC}\n" "$1"
}

summary() {
  local counters
  counters=$(cat "$SANITY_COUNTERS_FILE")
  local p f w
  read -r p f w <<<"$counters"
  # shellcheck disable=SC2059  # the _BOLD/_GREEN/... colour variables hold escape sequences the printf format must interpret
  printf "\n${_BOLD}════════════════════════${_NC}\n"
  # shellcheck disable=SC2059  # same colour escape sequences in the format as above
  printf "  Results: ${_GREEN}%d passed${_NC}, ${_RED}%d failed${_NC}, ${_YELLOW}%d warnings${_NC}\n" "$p" "$f" "$w"
  # shellcheck disable=SC2059  # same colour escape sequences in the format as above
  printf "${_BOLD}════════════════════════${_NC}\n"
  [ "$f" -eq 0 ]
}

# --- Command-form checks for the tests/test-*.sh files that keep their own tally.
# (Named check_cmd so the older files' own `check` — eval form — never clashes.)
CMD_PASS=0
CMD_FAIL=0

# check_cmd NAME CMD... — pass when the command succeeds.
check_cmd() {
  local name="$1"
  shift
  if "$@"; then
    CMD_PASS=$((CMD_PASS + 1))
    pass "$name"
  else
    CMD_FAIL=$((CMD_FAIL + 1))
    fail "$name"
  fi
}

# check_cmd_git ROOT NAME CMD... — check_cmd, but a warning (neither pass nor
# fail) when ROOT is not a git checkout: the copy the Docker flow makes has no
# .git, so checks that read the repo's tracked files or history cannot run.
check_cmd_git() {
  local root="$1" name="$2"
  shift 2
  if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    check_cmd "$name" "$@"
  else
    warn "$name (skipped: no git checkout)"
  fi
}

# cmd_summary — print "N passed, M failed" for the check_cmd tally and return
# non-zero when any failed.
cmd_summary() {
  echo ""
  echo "$CMD_PASS passed, $CMD_FAIL failed"
  [ "$CMD_FAIL" -eq 0 ]
}

# shellcheck source=../helpers/shell-utils.sh
_SCRIPT_DIR_HELPERS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_SCRIPT_DIR_HELPERS/../helpers/shell-utils.sh"
