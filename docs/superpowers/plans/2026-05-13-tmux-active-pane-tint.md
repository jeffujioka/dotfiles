# Active Pane Palette Tint — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tint the active tmux pane background with the palette's accent color (pfg) at 12% brightness, dynamically following palette changes.

**Architecture:** Add a `_darken_hex()` function to `bin/tmux-palette` that computes a darkened version of pfg using pure bash integer arithmetic. Both apply modes set `window-active-style` with the computed color. `tmux.conf` provides a static fallback.

**Tech Stack:** Bash (tmux-palette script), tmux options

---

### Task 1: Add `_darken_hex()` helper and extraction test

**Files:**
- Modify: `bin/tmux-palette` (add function after `_extract_palette`)
- Modify: `tests/test-tmux-palette.sh` (add darken unit tests)

- [ ] **Step 1: Write the failing test**

Add to `tests/test-tmux-palette.sh` after the existing extraction tests section (before `# --- Apply tests`):

```bash
echo ""
echo "=== Darken tests ==="

_test_darken() {
  local input="$1" pct="$2" expected="$3"
  local actual; actual=$("$PALETTE" --darken "$input" "$pct")
  _assert "darken $input @ ${pct}%" "$expected" "$actual"
}

_test_darken "#80e0a0" 12 "#0f1b13"
_test_darken "#ff0000" 12 "#1e0000"
_test_darken "#000000" 12 "#000000"
_test_darken "#ffffff" 12 "#1e1e1e"
_test_darken "#44ffaa" 12 "#081e14"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-tmux-palette.sh --extraction-only`
Expected: FAIL — `--darken` mode not recognized, output empty or error

- [ ] **Step 3: Add `_darken_hex()` function to `bin/tmux-palette`**

Insert after the `_extract_palette()` function (before `# --- Window status format ---`):

```bash
# --- Color math ---

_darken_hex() {
  local hex="${1#\#}" pct="${2:-12}"
  local r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
  printf '#%02x%02x%02x' $(( r * pct / 100 )) $(( g * pct / 100 )) $(( b * pct / 100 ))
}
```

- [ ] **Step 4: Add `--darken` CLI mode to `bin/tmux-palette`**

Handle `--darken` as a first-argument command before preset parsing. Also update usage.

In `usage()`, add a line after `--vars`:

```
  --darken    Darken a hex color by percentage (default 12%)
```

In the main section, replace:

```bash
preset="${1:-}"
mode="${2:---full}"

if [[ -z "$preset" || ! -f "$preset" ]]; then
  exit 0
fi
```

With:

```bash
# Standalone utility mode: tmux-palette --darken <#hex> [percent]
if [[ "${1:-}" == "--darken" ]]; then
  _darken_hex "${2:-}" "${3:-12}"
  exit 0
fi

preset="${1:-}"
mode="${2:---full}"

if [[ -z "$preset" || ! -f "$preset" ]]; then
  exit 0
fi
```

This makes `tmux-palette --darken "#80e0a0" 12` output `#0f1b13` without needing a preset file.

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test-tmux-palette.sh --extraction-only`
Expected: All darken tests PASS, all extraction tests PASS

- [ ] **Step 6: Commit**

```bash
git add bin/tmux-palette tests/test-tmux-palette.sh
git commit -m "feat(tmux-palette): add _darken_hex helper with --darken CLI mode"
```

---

### Task 2: Update `_apply_preview()` and `_apply_full()` to set window styles

**Files:**
- Modify: `bin/tmux-palette` (both apply functions)
- Modify: `tests/test-tmux-palette.sh` (add window-style assertions to apply tests)

- [ ] **Step 1: Write the failing test**

Add assertions to the existing `_test_preview` function in `tests/test-tmux-palette.sh`. After the existing `_assert "pane-active-border contains fg"` line, add:

```bash
  local wactive; wactive=$(tmux -L palette-test show-option -gv window-active-style)
  local wstyle; wstyle=$(tmux -L palette-test show-option -gv window-style)
  _assert "window-active-style has bg" "true" \
    "$([[ "$wactive" == *"bg=#"* ]] && echo true || echo false)"
  _assert "window-style is terminal" "true" \
    "$([[ "$wstyle" == *"bg=terminal"* ]] && echo true || echo false)"
```

Add the same two assertions to `_test_full`, after its existing `_assert "@dracula-colors contains palette"`:

```bash
  local wactive; wactive=$(tmux -L palette-test show-option -gv window-active-style)
  local wstyle; wstyle=$(tmux -L palette-test show-option -gv window-style)
  _assert "window-active-style has bg" "true" \
    "$([[ "$wactive" == *"bg=#"* ]] && echo true || echo false)"
  _assert "window-style is terminal" "true" \
    "$([[ "$wstyle" == *"bg=terminal"* ]] && echo true || echo false)"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test-tmux-palette.sh`
Expected: The new window-style assertions FAIL (window styles not yet set by palette)

- [ ] **Step 3: Update `_apply_preview()` in `bin/tmux-palette`**

Add at the end of `_apply_preview()`, before the closing `}`:

```bash
  local active_bg
  active_bg=$(_darken_hex "$pfg" 12)
  tmux set-option -g window-active-style "bg=$active_bg,fg=terminal"
  tmux set-option -g window-style "bg=terminal,fg=terminal"
  tmux set-option -g @palette-active-bg "$active_bg"
```

- [ ] **Step 4: Update `_apply_full()` in `bin/tmux-palette`**

Add at the end of `_apply_full()` (after the `tmux set-option -g @palette-pfg "$pfg"` line), before the closing `}`:

```bash
  local active_bg
  active_bg=$(_darken_hex "$pfg" 12)
  tmux set-option -g window-active-style "bg=$active_bg,fg=terminal"
  tmux set-option -g window-style "bg=terminal,fg=terminal"
  tmux set-option -g @palette-active-bg "$active_bg"
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash tests/test-tmux-palette.sh`
Expected: ALL tests PASS including the new window-style assertions

- [ ] **Step 6: Commit**

```bash
git add bin/tmux-palette tests/test-tmux-palette.sh
git commit -m "feat(tmux-palette): set window-active-style with darkened pfg in apply modes"
```

---

### Task 3: Update `tmux.conf` defaults and post-TPM override

**Files:**
- Modify: `tmux.conf` (lines 38-39 and line 227)

- [ ] **Step 1: Update static window style defaults**

Change line 38-39 from:

```
set -g window-active-style 'bg=terminal,fg=terminal'
set -g window-style 'bg=#2b2b2b,fg=colour246'
```

To:

```
set -g window-active-style 'bg=#0f1b13,fg=terminal'
set -g window-style 'bg=terminal,fg=terminal'
```

The `#0f1b13` is pre-computed from the default pfg `#80e0a0` at 12%.

- [ ] **Step 2: Update post-TPM run-shell override (line 227)**

Change:

```
run-shell -d 1 'c1="$(tmux show-option -gqv @palette-c1)"; pfg="$(tmux show-option -gqv @palette-pfg)"; tmux set-option -g pane-active-border-style "fg=${c1:-colour117},bg=${c1:-colour117}"; tmux set-option -g pane-border-style "fg=${pfg:-colour255}"'
```

To:

```
run-shell -d 1 'c1="$(tmux show-option -gqv @palette-c1)"; pfg="$(tmux show-option -gqv @palette-pfg)"; abg="$(tmux show-option -gqv @palette-active-bg)"; tmux set-option -g pane-active-border-style "fg=${c1:-colour117},bg=${c1:-colour117}"; tmux set-option -g pane-border-style "fg=${pfg:-colour255}"; tmux set-option -g window-active-style "bg=${abg:-#0f1b13},fg=terminal"; tmux set-option -g window-style "bg=terminal,fg=terminal"'
```

This reads the `@palette-active-bg` value that `tmux-palette` already computed and applies it after TPM runs (preventing Dracula from resetting it).

- [ ] **Step 3: Verify tmux config syntax**

Run: `tmux -f /home/jfujiok/.dotfiles/tmux.conf start-server \; kill-server 2>&1 | head -5`
Expected: No syntax errors (empty output or clean exit)

- [ ] **Step 4: Commit**

```bash
git add tmux.conf
git commit -m "feat(tmux): update window styles for active pane tint with palette fallback"
```

---

### Task 4: Manual verification and cleanup

- [ ] **Step 1: Run full test suite**

Run: `bash tests/test-tmux-palette.sh`
Expected: ALL tests PASS, 0 failures

- [ ] **Step 2: Test live in tmux**

Reload the config in your active tmux session:

```bash
tmux source-file ~/.tmux.conf
```

Verify:
- Active pane has a visible green tint (Forest palette)
- Inactive pane(s) have pure terminal background (black)
- Text is fully readable in both panes
- Switching focus immediately updates which pane is tinted

- [ ] **Step 3: Test palette switch**

Switch to a different starship preset and re-apply:

```bash
# Try ocean palette
ln -sf ~/.dotfiles/config/starship/presets/starship-powerline-gradient-ocean.toml ~/.config/starship/config.toml
~/.dotfiles/bin/tmux-palette "$(readlink ~/.config/starship/config.toml)" --full
```

Verify the active pane tint changes to a blue tint instead of green.

Restore the original preset when done:

```bash
ln -sf ~/.dotfiles/config/starship/config.toml ~/.config/starship/config.toml
~/.dotfiles/bin/tmux-palette "$(readlink ~/.config/starship/config.toml)" --full
```

- [ ] **Step 4: Commit spec fix (pct arg)**

```bash
git add docs/superpowers/specs/2026-05-13-tmux-active-pane-tint-design.md
git commit -m "docs: fix _darken_hex arg in spec (integer pct, not float)"
```
