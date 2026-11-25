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

PASS=0
FAIL=0

# check NAME CONDITION_COMMAND... — pass when the command succeeds.
check() {
  local name="$1"
  shift
  if "$@"; then
    PASS=$((PASS + 1))
    pass "$name"
  else
    FAIL=$((FAIL + 1))
    fail "$name"
  fi
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

t_shellcheck_clean() {
  local files=() f
  while IFS= read -r f; do files+=("$f"); done < <(shell_files)
  [ "${#files[@]}" -gt 0 ] || return 1
  (cd "$REPO_ROOT" && shellcheck "${files[@]}" >/dev/null)
}
check "ShellCheck reports nothing on the repository's shell files" t_shellcheck_clean

# A directive line is a comment starting with `shellcheck disable=`; it needs
# `# text` after the code list on the same line.
t_disable_reasons() {
  local bad
  bad="$(cd "$REPO_ROOT" && git grep -nE '^[[:space:]]*#[[:space:]]*shellcheck[[:space:]]+disable=' \
    | grep -vE 'disable=[A-Za-z0-9,]+[[:space:]]+#[[:space:]]*[^[:space:]]')" || true
  [ -z "$bad" ] || {
    echo "$bad" >&2
    return 1
  }
}
check "every shellcheck disable directive has a reason" t_disable_reasons

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
