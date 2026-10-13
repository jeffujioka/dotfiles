#!/bin/env bash

claude_update_all_plugins() (
  json=$(claude plugin list --json) || exit $?
  names=$(printf '%s\n' "$json" | jq -r '.[].id | split("@")[0]') || exit $?
  [ -n "$names" ] || exit 0

  printf '%s\n' "$names" |
    while IFS= read -r plugin; do
      claude plugin update "$plugin" || exit $?
    done
)

upd() {
  brew update || true
  brew upgrade || true
  echo '################################################################################'
  echo '... Updating Claude Code...'
  echo '################################################################################'
  claude --update || true
  if command -v openchamber >/dev/null; then
    echo '################################################################################'
    echo '... Updating OpenChamber...'
    echo '################################################################################'
    openchamber update || true
  fi
  echo '################################################################################'
  echo '... Updating skills...'
  echo '################################################################################'
  DISABLE_TELEMETRY=1 npx --yes skills@latest update -g -y || true
  echo '################################################################################'
  echo '... Updating claude plugins...'
  echo '################################################################################'
  claude_update_all_plugins || true
  echo '################################################################################'
  echo '... Updating opencode plugins...'
  echo '################################################################################'
  opencode plugin update || true
}
alias ccupd="claude --update"
alias bupd="brew update && brew upgrade -y"
alias yupd="DISABLE_TELEMETRY=1 npx --yes skills@latest update -g -y"
alias opupd="openchamber update"
alias ccuap="claude_update_all_plugins"
