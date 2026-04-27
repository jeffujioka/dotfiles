#!/usr/bin/env bash
# Automated tmux-palette extraction + apply validation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PALETTE="$REPO_ROOT/bin/tmux-palette"
PRESETS="$REPO_ROOT/config/starship/presets"

EXTRACTION_ONLY=false
[[ "${1:-}" == "--extraction-only" ]] && EXTRACTION_ONLY=true

pass=0 fail=0

_assert() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf '  ✓ %s\n' "$label"; pass=$((pass + 1))
  else
    printf '  ✗ %s — expected: %s, got: %s\n' "$label" "$expected" "$actual"; fail=$((fail + 1))
  fi
}

_get_var() { echo "$1" | grep "^$2=" | cut -d= -f2; }

# --- Extraction tests (no tmux required) ---

_test_extraction() {
  local preset="$1" e_c1="$2" e_c2="$3" e_c3="$4" e_c4="$5" e_c5="$6" e_pfg="$7" e_bracket="$8"
  local label; label=$(basename "$preset" .toml | sed 's/^starship-//')
  printf '%s\n' "$label"
  local out; out=$("$PALETTE" "$PRESETS/$preset" --vars)
  _assert "c1" "$e_c1" "$(_get_var "$out" c1)"
  _assert "c2" "$e_c2" "$(_get_var "$out" c2)"
  _assert "c3" "$e_c3" "$(_get_var "$out" c3)"
  _assert "c4" "$e_c4" "$(_get_var "$out" c4)"
  _assert "c5" "$e_c5" "$(_get_var "$out" c5)"
  _assert "pfg" "$e_pfg" "$(_get_var "$out" pfg)"
  _assert "is_bracket" "$e_bracket" "$(_get_var "$out" is_bracket)"
}

echo "=== Extraction tests ==="

_test_extraction "starship-bubble-gradient-aurora-deep.toml" \
  "#00a850" "#002a12" "#061838" "#120630" "#0c0620" "#44ffaa" "false"

_test_extraction "starship-bracket-aurora.toml" \
  "#00e888" "#00c8a0" "#20a8c0" "#7060d0" "#9050b0" "#00c8a0" "true"

_test_extraction "starship-powerline-gradient-ocean.toml" \
  "#083028" "#082830" "#081828" "#081028" "#080c20" "#80e0d0" "false"

_test_extraction "starship-clean-gradient-ocean.toml" \
  "#20b8b0" "#083028" "#081828" "#081028" "#080c20" "#40e0d0" "false"

# --- Apply tests (tmux required) ---

if ! $EXTRACTION_ONLY; then

echo ""
echo "=== Apply tests (tmux) ==="

tmux -L palette-test new-session -d -s test 2>/dev/null

_test_preview() {
  local preset="$1" e_status_bg="$2" e_border="$3"
  local label; label=$(basename "$preset" .toml | sed 's/^starship-//')
  printf '%s --preview\n' "$label"

  TMUX="/tmp/tmux-palette-test/palette-test,0,0" \
    "$PALETTE" "$PRESETS/$preset" --preview

  local status; status=$(tmux -L palette-test show-option -gv status-style)
  local border; border=$(tmux -L palette-test show-option -gv pane-active-border-style)

  _assert "status-style contains bg" "true" \
    "$([[ "$status" == *"$e_status_bg"* ]] && echo true || echo false)"
  _assert "pane-active-border contains fg" "true" \
    "$([[ "$border" == *"$e_border"* ]] && echo true || echo false)"
}

_test_full() {
  local preset="$1" e_dracula_has="$2"
  local label; label=$(basename "$preset" .toml | sed 's/^starship-//')
  printf '%s --full\n' "$label"

  TMUX="/tmp/tmux-palette-test/palette-test,0,0" \
    "$PALETTE" "$PRESETS/$preset" --full

  local colors; colors=$(tmux -L palette-test show-option -gv @dracula-colors 2>/dev/null || echo "")
  _assert "@dracula-colors contains palette" "true" \
    "$([[ "$colors" == *"$e_dracula_has"* ]] && echo true || echo false)"
}

_test_preview "starship-bubble-gradient-aurora-deep.toml" "#0c0620" "#00a850"
_test_preview "starship-bracket-aurora.toml" "default" "#00e888"
_test_full "starship-bubble-gradient-aurora-deep.toml" "#00a850"
_test_full "starship-bracket-aurora.toml" "#00e888"

tmux -L palette-test kill-server 2>/dev/null || true

fi  # end !EXTRACTION_ONLY

echo ""
printf '=== Results: %d passed, %d failed ===\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
