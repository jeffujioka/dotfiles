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

alias upd='
    brew update && brew upgrade -y && claude --update &&
    openchamber update &&
    DISABLE_TELEMETRY=1 npx skills@latest update -g -y &&
    ccuap &&
    opencode plugin update
'
alias ccupd="claude --update"
alias bupd="brew update && brew upgrade -y"
alias yupd="DISABLE_TELEMETRY=1 npx skills@latest update -g -y"
alias opupd="openchamber update"
alias ccuap="claude_update_all_plugins"
