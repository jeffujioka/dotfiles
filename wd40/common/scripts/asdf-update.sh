#!/bin/bash
#
# asdf-update.sh - install the newest version of every asdf plugin and make it the global default.
#
# wd40: asdf-update - install the newest version of each asdf plugin and write it to ~/.tool-versions (--weekly: at most once a week)
#
# For each installed plugin: `asdf latest`, `asdf install`, then `asdf set
# --home` so ~/.tool-versions names that version. Runs from $HOME so a repo's
# own .tool-versions pin can never be picked up or overwritten. ~/.tool-versions
# is only written after the install succeeded, so it never names a version that
# is not installed. Old versions are never uninstalled: repos may still pin them.
# A plugin that cannot report a latest version is skipped with a warning.
#
# Usage: asdf-update [--weekly]
#   --weekly   do nothing when the last fully successful run was under 7 days ago

set -u

weekly=0
case "${1:-}" in
  "") ;;
  --weekly) weekly=1 ;;
  *) echo "usage: asdf-update [--weekly]" >&2; exit 2 ;;
esac

if ! command -v asdf >/dev/null 2>&1; then
  echo "asdf-update: asdf not found on PATH" >&2
  exit 1
fi

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
stamp="$state_dir/asdf-update.stamp"
week_minutes=10080

if [ "$weekly" = 1 ] && [ -f "$stamp" ] && [ -z "$(find "$stamp" -mmin +"$week_minutes" 2>/dev/null)" ]; then
  exit 0
fi

cd "$HOME" || exit 1

failed=0
for plugin in $(asdf plugin list 2>/dev/null); do
  latest=$(asdf latest "$plugin" 2>/dev/null | tail -n 1)
  case "$latest" in
    "" | *[[:space:]]*)
      echo "asdf-update: $plugin: no latest version available, skipping" >&2
      continue
      ;;
  esac

  if ! asdf install "$plugin" "$latest"; then
    echo "asdf-update: $plugin: install of $latest failed, ~/.tool-versions unchanged" >&2
    failed=1
    continue
  fi

  current=$(awk -v p="$plugin" '$1 == p { print $2; exit }' "$HOME/.tool-versions" 2>/dev/null)
  [ "$current" = "$latest" ] && continue

  if asdf set --home "$plugin" "$latest"; then
    echo "asdf-update: $plugin ${current:-none} -> $latest"
  else
    echo "asdf-update: $plugin: could not set $latest in ~/.tool-versions" >&2
    failed=1
  fi
done

if [ "$failed" = 0 ]; then
  mkdir -p "$state_dir" && touch "$stamp"
fi
exit "$failed"
