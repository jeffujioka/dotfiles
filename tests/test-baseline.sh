#!/bin/bash
# Clean-baseline tests: the repo as committed passes the lint tools. The file
# selection comes from `./test.sh lint-files`, the same function `./test.sh
# lint` uses. Keeps its own PASS/FAIL tally; later tasks add their checks
# below, with the `check` helper.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=helpers.sh
. "$SCRIPT_DIR/helpers.sh"

section "Clean baseline"

PASS=0; FAIL=0

# check NAME CONDITION_COMMAND... — pass when the command succeeds.
check() {
  local name="$1"; shift
  if "$@"; then PASS=$((PASS+1)); pass "$name"
  else FAIL=$((FAIL+1)); fail "$name"; fi
}

# shell_files — the bash/sh files lint checks, one per line.
shell_files() { "$REPO_ROOT/test.sh" lint-files; }

t_shfmt_bash() {
  local files=() f
  while IFS= read -r f; do files+=("$f"); done < <(shell_files)
  [ "${#files[@]}" -gt 0 ] || return 1
  (cd "$REPO_ROOT" && shfmt -d "${files[@]}" >/dev/null)
}
check "shfmt reports no diff on bash and sh scripts" t_shfmt_bash

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
