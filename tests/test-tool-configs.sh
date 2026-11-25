#!/bin/bash
# Behaviour tests for the lint/format tool configs: the user-level Biome and
# ShellCheck configs under config/, the repo's biome.jsonc and the manifest's
# linter formulas. Uses the installed biome/shellcheck in a sandboxed HOME so
# no real user config leaks in. Keeps its own PASS/FAIL tally; later tasks add
# their checks below, with the `check` helper.
#
# TOOL_CONFIG_ROOT (default: the repo) points at the tree holding the configs;
# the tests copy broken trees there to show they can fail.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="${TOOL_CONFIG_ROOT:-$REPO_ROOT}"

# shellcheck source=helpers.sh
. "$SCRIPT_DIR/helpers.sh"

section "Tool configs (Biome, ShellCheck, shfmt)"

PASS=0; FAIL=0
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

# check NAME CONDITION_COMMAND... — pass when the command succeeds.
check() {
  local name="$1"; shift
  if "$@"; then PASS=$((PASS+1)); pass "$name"
  else FAIL=$((FAIL+1)); fail "$name"; fi
}

# new_home — fresh sandbox HOME with the user-level configs installed where
# the tools look: Biome at ~/.config/biome and (macOS) ~/Library/Application
# Support/biome, ShellCheck at ~/.shellcheckrc. Echoes the path.
new_home() {
  local h
  h=$(mktemp -d "$SANDBOX/home.XXXXXX")
  mkdir -p "$h/.config" "$h/Library/Application Support"
  [ -d "$ROOT/config/biome" ] && ln -s "$ROOT/config/biome" "$h/.config/biome"
  [ -d "$ROOT/config/biome" ] && ln -s "$ROOT/config/biome" "$h/Library/Application Support/biome"
  [ -f "$ROOT/config/shellcheck/shellcheckrc" ] \
    && ln -s "$ROOT/config/shellcheck/shellcheckrc" "$h/.shellcheckrc"
  [ -f "$ROOT/config/shfmt/editorconfig" ] \
    && ln -s "$ROOT/config/shfmt/editorconfig" "$h/.editorconfig"
  echo "$h"
}

# in_home HOME CMD... — run CMD with HOME (and XDG) pointed at the sandbox.
in_home() {
  local h="$1"; shift
  env -u XDG_CONFIG_HOME -u BIOME_CONFIG_PATH HOME="$h" XDG_CONFIG_HOME="$h/.config" "$@"
}

# manifest_formulas PLATFORM — brew formulas installed on PLATFORM.
manifest_formulas() {
  "$REPO_ROOT/helpers/read-manifest.py" brew.tools --format tsv --fields "formula,platform:" --manifest "$ROOT/manifest.toml" \
    | awk -F'\t' -v p="$1" '$2 == "" || $2 == p { print $1 }'
}

t_formulas_both_platforms() {
  local p f list
  for p in darwin linux; do
    list=$(manifest_formulas "$p")
    for f in biome shellcheck shfmt; do
      printf '%s\n' "$list" | grep -qx "$f" || { echo "    $f missing on $p" >&2; return 1; }
    done
  done
}
check "biome, shellcheck and shfmt install on darwin and linux" t_formulas_both_platforms

t_biome_formats_js() {
  local h work out
  h=$(new_home); work=$(mktemp -d "$SANDBOX/work.XXXXXX")
  printf 'const a = "x";\nfunction f() {\n    return a;\n}\n' > "$work/a.js"
  (cd "$work" && in_home "$h" biome format --write a.js >/dev/null 2>&1)
  out=$(cat "$work/a.js")
  [ "$out" = "$(printf "const a = 'x';\nfunction f() {\n  return a;\n}")" ] \
    || { echo "    got: $out" >&2; return 1; }
}
check "user-level Biome config formats JavaScript to the house style" t_biome_formats_js

t_biome_md_untouched() {
  local h work
  h=$(new_home); work=$(mktemp -d "$SANDBOX/work.XXXXXX")
  printf -- '---\ntitle: x\ntags: [a]\n---\n\n* item\n*   other\n' > "$work/n.md"
  cp "$work/n.md" "$work/n.orig"
  (cd "$work" && in_home "$h" biome format --write n.md >/dev/null 2>&1)
  cmp -s "$work/n.md" "$work/n.orig"
}
check "user-level Biome config leaves Markdown with frontmatter unchanged" t_biome_md_untouched

t_shellcheck_source() {
  local h work out
  h=$(new_home); work=$(mktemp -d "$SANDBOX/work.XXXXXX")
  printf 'GREETING=hi\nexport GREETING\n' > "$work/lib.sh"
  printf '#!/bin/bash\nset -u\n. lib.sh\necho "$GREETING"\n' > "$work/main.sh"
  out=$(cd "$work" && in_home "$h" shellcheck -f gcc main.sh 2>&1) \
    || { echo "    $out" >&2; return 1; }
  ! printf '%s' "$out" | grep -q 'SC2154'
}
check "ShellCheck follows a relative source with the user-level config" t_shellcheck_source

# project_biome — project dir with the repo's biome.jsonc, a git repo so
# useIgnoreFile works; echoes the path.
project_biome() {
  local d
  d=$(mktemp -d "$SANDBOX/proj.XXXXXX")
  cp "$ROOT/biome.jsonc" "$d/biome.jsonc"
  git -C "$d" init -q
  echo "$d"
}

t_repo_biome_md() {
  local h d
  h=$(new_home); d=$(project_biome)
  printf -- '---\ntitle: x\n---\n\n# Heading\n\ntext\n' > "$d/n.md"
  cp "$d/n.md" "$d/n.orig"
  (cd "$d" && in_home "$h" biome check >/dev/null 2>&1) || return 1
  cmp -s "$d/n.md" "$d/n.orig"
}
check "repo Biome config keeps Markdown frontmatter" t_repo_biome_md

t_repo_biome_ignores() {
  local h d out
  h=$(new_home); d=$(project_biome)
  printf '# T\n' > "$d/n.md"
  printf 'const a = "x"\n' > "$d/a.js"
  printf '{"a":   1,\n"b":2}\n' > "$d/a.json"
  out=$(cd "$d" && in_home "$h" biome check 2>&1) || { echo "    $out" >&2; return 1; }
  ! printf '%s' "$out" | grep -Eq 'a\.(js|json)'
}
check "repo Biome config ignores JavaScript and JSON" t_repo_biome_ignores

t_shfmt_house_style() {
  local h work
  h=$(new_home); work=$(mktemp -d "$h/work.XXXXXX")
  printf '#!/bin/bash\ncase "$1" in\n  a)\n    echo a\n    ;;\nesac\necho x \\\n  | cat\n' > "$work/good.sh"
  printf '#!/bin/bash\ncase "$1" in\n    a)\n        echo a\n        ;;\nesac\necho x \\\n    | cat\n' > "$work/bad.sh"
  (cd "$work" && in_home "$h" shfmt -d good.sh >/dev/null 2>&1) || return 1
  ! (cd "$work" && in_home "$h" shfmt -d bad.sh >/dev/null 2>&1)
}
check "user-level shfmt config indents to the house style" t_shfmt_house_style

t_shfmt_only_shell() {
  local f="$ROOT/config/shfmt/editorconfig" headers
  [ -f "$f" ] || return 1
  headers=$(grep -E '^[[:space:]]*\[' "$f")
  [ "$headers" = "[[shell]]" ]
}
check "shfmt config has only the [[shell]] section" t_shfmt_only_shell

# repo_link NAME TARGET — NAME in the repo is a symlink to TARGET.
repo_link() {
  [ -L "$ROOT/$1" ] && [ "$(readlink "$ROOT/$1")" = "$2" ]
}
check ".editorconfig links to config/shfmt/editorconfig" repo_link .editorconfig config/shfmt/editorconfig
check ".shellcheckrc links to config/shellcheck/shellcheckrc" repo_link .shellcheckrc config/shellcheck/shellcheckrc

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
