# Tmux Active Pane Palette Tint

## Problem

The current inactive pane dimming (`bg=#2b2b2b,fg=colour246`) uses a neutral grey that looks like a rendering glitch rather than a deliberate visual signal. The goal is to clearly indicate which pane is active using a palette-derived color that feels intentional and cohesive with the starship/tmux theme.

## Design

Invert the highlighting model: instead of dimming inactive panes, **tint the active pane** with the palette's accent color at low brightness. Inactive panes use the plain terminal background.

### Pane Styles

| Pane State | Background | Foreground |
|---|---|---|
| Active | `pfg * 0.12` (palette accent at 12% brightness) | `terminal` |
| Inactive | `terminal` (transparent/black) | `terminal` |

### Color Derivation

The active pane background is computed by scaling each RGB channel of `pfg` to 12%:

```
pfg = #80e0a0  (Forest palette example)
R: 0x80 * 0.12 = 0x0F
G: 0xe0 * 0.12 = 0x1B
B: 0xa0 * 0.12 = 0x13
active_bg = #0f1b13
```

This produces a very dark tint that is clearly distinguishable from pure black while remaining comfortable for extended use.

### Dynamic Behavior

The tint updates automatically when the starship palette changes (via `tmux-palette`). Each palette produces its own characteristic tint:
- Forest: dark green tint
- Ocean: dark blue tint
- Synthwave: dark purple tint
- Inferno: dark red/amber tint

### Always-On

The tint applies unconditionally, even when only one pane exists. It becomes part of the terminal's visual identity rather than a conditional distinction tool.

## Implementation

### Files Modified

1. **`bin/tmux-palette`**
   - Add `_darken_hex()` helper: takes a hex color and a scale factor (0.12), returns the darkened hex
   - Update `_apply_full()`: set `window-active-style` and `window-style` using the computed color
   - Update `_apply_preview()`: same as above
   - Store result as `@palette-active-bg` tmux option

2. **`tmux.conf`**
   - Change `window-active-style` from `'bg=terminal,fg=terminal'` to `'bg=#0f1b13,fg=terminal'` (static fallback for default palette)
   - Change `window-style` from `'bg=#2b2b2b,fg=colour246'` to `'bg=terminal,fg=terminal'`

### `_darken_hex()` Function

Pure bash integer arithmetic (no `bc` dependency, portable):

```bash
_darken_hex() {
  local hex="${1#\#}" pct="${2:-12}"
  local r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
  printf '#%02x%02x%02x' $(( r * pct / 100 )) $(( g * pct / 100 )) $(( b * pct / 100 ))
}
```

Usage: `_darken_hex "#80e0a0" 12` → `#0f1b13`

### Apply Functions (additions)

```bash
# In _apply_full and _apply_preview:
local active_bg
active_bg=$(_darken_hex "$pfg" 12)
tmux set-option -g window-active-style "bg=$active_bg,fg=terminal"
tmux set-option -g window-style "bg=terminal,fg=terminal"
tmux set-option -g @palette-active-bg "$active_bg"
```

## Coexistence

The `tmux-border-pulse` script remains as a separate optional feature. Both can be active simultaneously — the border pulse affects `pane-active-border-style` while this feature affects `window-active-style`.

## Fallback

When `tmux-palette` has not yet run (e.g., no starship preset symlinked), `tmux.conf` provides a static default: `window-active-style 'bg=#0f1b13,fg=terminal'` (pre-computed from the default pfg `#80e0a0` at 12%). The existing post-TPM `run-shell` block (line 227 in tmux.conf) should also set `window-active-style` and `window-style` alongside the border styles it already configures.
