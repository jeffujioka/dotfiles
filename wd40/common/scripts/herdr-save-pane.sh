#!/usr/bin/env bash
# wd40: herdr-save-pane - save a Herdr pane's scrollback to $TMPDIR/herdr-<YY.MM.DD-HH:MM:SS>.log
# Meant for a Herdr `type = "popup"` key command: saves the pane underneath, copies the path with pbcopy, shows it.
set -euo pipefail

# Herdr runs key commands with the server's minimal env: no user bin dirs, no TMPDIR.
export PATH="$HOME/.local/bin:$HOME/.homebrew/bin:/opt/homebrew/bin:$PATH"
TMPDIR="${TMPDIR:-$HOME/.local/tmp}"
mkdir -p "$TMPDIR"

# A popup has no HERDR_PANE_ID; HERDR_ACTIVE_PANE_ID is the tiled pane underneath.
pane="${HERDR_ACTIVE_PANE_ID:-$(herdr pane current | jq -r '.result.pane.pane_id')}"

out="$TMPDIR/herdr-$(date +%y.%m.%d-%H:%M:%S).log"
herdr pane read "$pane" --source recent-unwrapped --lines 100000 >"$out"

if printf '%s' "$out" | pbcopy; then copied="Path copied to clipboard."; else copied="Could not copy path to clipboard."; fi

printf 'Saved pane %s to:\n\n  %s\n\n%s Press any key to close.' "$pane" "$out" "$copied"
read -r -s -n 1 || true
