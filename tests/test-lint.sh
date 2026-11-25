#!/bin/bash
# Behaviour tests for `./test.sh lint`. Every case builds a throwaway git repo
# holding a copy of test.sh and the lint configs, so the command's
# SCRIPT_DIR-relative file selection runs against the fixture, never the real
# repo. Keeps its own PASS/FAIL tally with the `check` helper.
#
# LINT_TEST_SH (default: the repo's test.sh) is the script under test; the
# tests point it at a broken copy to show they can fail.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_SH="${LINT_TEST_SH:-$REPO_ROOT/test.sh}"

# shellcheck source=helpers.sh
. "$SCRIPT_DIR/helpers.sh"

section "Lint command"

PASS=0
FAIL=0
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

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

# new_fixture — git repo with the lint configs and one clean script and
# Markdown file, all tracked, plus an untracked copy of test.sh (the real one
# is not lint-clean until the baseline task, so it must stay out of the
# fixture's file list). Echoes the path.
new_fixture() {
  local d
  d=$(mktemp -d "$SANDBOX/repo.XXXXXX")
  cp "$TEST_SH" "$d/test.sh"
  cp -L "$REPO_ROOT/.editorconfig" "$REPO_ROOT/.shellcheckrc" "$REPO_ROOT/biome.jsonc" "$d/"
  printf '#!/bin/bash\necho "$1"\n' >"$d/good.sh"
  chmod +x "$d/good.sh" "$d/test.sh"
  printf '# Title\n\n- item\n' >"$d/README.md"
  git -C "$d" init -q
  # The negation mirrors the repo's .gitignore: a global `_*` ignore would
  # otherwise keep the completion files out of the fixture.
  printf 'test.sh\nout\n!zsh_completions.d/_*\n' >"$d/.git/info/exclude"
  echo "$d"
}

# fixture_lint DIR [PATH] — run `./test.sh lint` in DIR; output in DIR/out,
# status returned.
fixture_lint() {
  local rc=0
  (cd "$1" && git add -A && PATH="${2:-$PATH}" ./test.sh lint) >"$1/out" 2>&1 || rc=$?
  return "$rc"
}

t_clean() {
  local d
  d=$(new_fixture)
  fixture_lint "$d" || return 1
  grep -q '^== ShellCheck' "$d/out" && grep -q '^== shfmt' "$d/out" && grep -q '^== Biome' "$d/out"
}
check "clean fixture passes with three headings" t_clean

t_shellcheck() {
  local d
  d=$(new_fixture)
  printf '#!/bin/bash\nrm -rf $1\n' >"$d/bad.sh"
  ! fixture_lint "$d" && grep -q 'SC2086' "$d/out"
}
check "ShellCheck finding fails lint" t_shellcheck

t_shfmt_bash() {
  local d
  d=$(new_fixture)
  printf '#!/bin/bash\nif true; then\n    echo "$1"\nfi\n' >"$d/four.sh"
  ! fixture_lint "$d" && grep -q -- '--- four.sh' "$d/out"
}
check "unformatted bash script fails lint" t_shfmt_bash

t_shfmt_zsh() {
  local d
  d=$(new_fixture)
  printf '#!/usr/bin/zsh\nif true; then\n    print -r -- "$1"\nfi\n' >"$d/zshrc"
  ! fixture_lint "$d" && grep -q -- '--- zshrc' "$d/out"
}
check "unformatted zsh file fails lint" t_shfmt_zsh

t_markdown() {
  local d
  d=$(new_fixture)
  printf '# Title\n\n* item\n' >"$d/notes.md"
  ! fixture_lint "$d" && grep -q 'notes.md' "$d/out"
}
check "unformatted Markdown fails lint" t_markdown

t_missing_shfmt() {
  local d bin t rc=0
  d=$(new_fixture)
  bin=$(mktemp -d "$SANDBOX/bin.XXXXXX")
  for t in shellcheck biome; do ln -s "$(command -v "$t")" "$bin/$t"; done
  # /usr/bin and /bin supply git and coreutils; neither holds shfmt.
  fixture_lint "$d" "$bin:/usr/bin:/bin" || rc=$?
  [ "$rc" -eq 1 ] && grep -qx 'Error: shfmt not found (run ./install.sh)' "$d/out"
}
check "missing shfmt is refused with exit 1" t_missing_shfmt

t_zsh_shebang_skipped() {
  local d
  d=$(new_fixture)
  printf '#!/usr/bin/zsh\nfor f in *(N); do print -r -- "${f:t}"; done\n' >"$d/other.zsh-script"
  fixture_lint "$d"
}
check "unlisted zsh-shebang file is skipped" t_zsh_shebang_skipped

t_generated_completions() {
  local d f
  d=$(new_fixture)
  mkdir "$d/zsh_completions.d"
  for f in _bun _opencode _starship; do
    # A bash shebang would select the file anywhere else in the repo.
    printf '#!/bin/bash\n#compdef %s\n_x() {\n        echo $1\n}\n' "${f#_}" >"$d/zsh_completions.d/$f"
  done
  fixture_lint "$d"
}
check "generated completions are not checked" t_generated_completions

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
