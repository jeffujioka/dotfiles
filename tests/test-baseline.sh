#!/bin/bash
# Clean-baseline tests: the repo as committed passes the lint tools. The file
# selection comes from `./test.sh lint-files`, the same function `./test.sh
# lint` uses. They read the repo's tracked files, so without a git checkout
# (the Docker flow copies the repo without .git) they warn and skip. Keeps its
# own tally (helpers.sh); later tasks add their checks below, with the
# `check_cmd` helper.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=helpers.sh
. "$SCRIPT_DIR/helpers.sh"

section "Clean baseline"

# shell_files — the bash/sh files lint checks, one per line.
shell_files() { "$REPO_ROOT/test.sh" lint-files; }

t_shfmt_bash() {
  local files=() f
  while IFS= read -r f; do files+=("$f"); done < <(shell_files)
  [ "${#files[@]}" -gt 0 ] || return 1
  (cd "$REPO_ROOT" && shfmt -d "${files[@]}" >/dev/null)
}
check_cmd_git "$REPO_ROOT" "shfmt reports no diff on bash and sh scripts" t_shfmt_bash

t_shellcheck_clean() {
  local files=() f
  while IFS= read -r f; do files+=("$f"); done < <(shell_files)
  [ "${#files[@]}" -gt 0 ] || return 1
  (cd "$REPO_ROOT" && shellcheck "${files[@]}" >/dev/null)
}
check_cmd_git "$REPO_ROOT" "ShellCheck reports nothing on the repository's shell files" t_shellcheck_clean

# A directive line is a comment starting with `shellcheck disable=`; it needs
# `# text` after the code list on the same line. `git grep` exits 1 when it
# finds nothing, which is fine; any higher status is an error, so a failing
# `git grep` cannot pass the check.
t_disable_reasons() {
  local found rc=0 bad
  found="$(cd "$REPO_ROOT" && git grep -nE '^[[:space:]]*#[[:space:]]*shellcheck[[:space:]]+disable=')" || rc=$?
  [ "$rc" -le 1 ] || return 1
  bad="$(printf '%s\n' "$found" | grep -vE 'disable=[A-Za-z0-9,]+[[:space:]]+#[[:space:]]*[^[:space:]]' || true)"
  [ -z "$bad" ] || {
    echo "$bad" >&2
    return 1
  }
}
check_cmd_git "$REPO_ROOT" "every shellcheck disable directive has a reason" t_disable_reasons

# zsh_files — the hand-written zsh files (D7), one per line.
zsh_files() { "$REPO_ROOT/test.sh" lint-zsh-files; }

t_shfmt_zsh() {
  local files=() f
  while IFS= read -r f; do files+=("$f"); done < <(zsh_files)
  [ "${#files[@]}" -gt 0 ] || return 1
  (cd "$REPO_ROOT" && shfmt -ln zsh -d "${files[@]}" >/dev/null)
}
check_cmd_git "$REPO_ROOT" "shfmt -ln zsh reports no diff on the hand-written zsh files" t_shfmt_zsh

# ZSH_PARSE_ROOT overrides the directory the files are read from, so the test
# can be shown failing on a deliberately broken copy.
t_zsh_parse() {
  local files=() f root="${ZSH_PARSE_ROOT:-$REPO_ROOT}"
  while IFS= read -r f; do files+=("$f"); done < <(zsh_files)
  [ "${#files[@]}" -gt 0 ] || return 1
  for f in "${files[@]}"; do
    (cd "$root" && zsh -n "$f") || return 1
  done
}
check_cmd_git "$REPO_ROOT" "hand-written zsh files pass zsh -n" t_zsh_parse

# LINT_ROOT overrides the checkout whose test.sh runs, so the test can be shown
# failing on a deliberately broken copy. HOME is an empty sandbox: lint must
# rely on the repo's own configs only.
t_lint_passes() {
  local root="${LINT_ROOT:-$REPO_ROOT}" home rc=0
  home=$(mktemp -d)
  env -u XDG_CONFIG_HOME -u BIOME_CONFIG_PATH HOME="$home" "$root/test.sh" lint >/dev/null 2>&1 || rc=$?
  rm -rf "$home"
  return "$rc"
}
check_cmd_git "${LINT_ROOT:-$REPO_ROOT}" "./test.sh lint exits 0" t_lint_passes

cmd_summary
