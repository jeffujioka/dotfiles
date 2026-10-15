#!/bin/env bash
# wd40: upd - update brew, Claude Code, OpenChamber, skills, plugins, and zsh completions, then restart zsh (--no-restart to skip)
# wd40: zcomp-update - regenerate zsh completion scripts for installed CLIs and rebuild the dump, then restart zsh (--no-restart to skip)

claude_update_all_plugins() (
  json=$(claude plugin list --json) || exit $?
  names=$(printf '%s\n' "$json" | jq -r '.[].id | split("@")[0]') || exit $?
  [ -n "$names" ] || exit 0

  rc=0
  while IFS= read -r plugin; do
    claude plugin update "$plugin" || rc=1
  done <<EOF
$names
EOF
  exit "$rc"
)

_zcomp_gen_cmd() {
  case "$1" in
    opencode) echo "--completions zsh" ;;
    gh | glab) echo "completion -s zsh" ;;
    acli | docker | asdf | glow | git-lfs) echo "completion zsh" ;;
    bun | starship | tv) echo "completions zsh" ;;
    procs) echo "--gen-completion-out zsh" ;;
    bat) echo "--completion zsh" ;;
    uv | uvx) echo "--generate-shell-completion zsh" ;;
    ruff) echo "generate-shell-completion zsh" ;;
    rg) echo "--generate complete-zsh" ;;
    fd) echo "--gen-completions zsh" ;;
  esac
}

# Replace the current shell with a fresh zsh. $1 is an optional failure
# summary, handed over through UPD_SUMMARY and printed by _upd_report.
# Returns 1 when the shell was not replaced (non-zsh, non-interactive, jobs).
_upd_restart_shell() {
  [ -n "${ZSH_VERSION:-}" ] || return 1
  case $- in *i*) ;; *) return 1 ;; esac
  if [ "${#jobstates}" -gt 0 ]; then
    echo "upd: background jobs exist, not restarting the shell" >&2
    return 1
  fi
  [ -n "$1" ] && export UPD_SUMMARY="$1"
  exec zsh
  unset UPD_SUMMARY
  return 1
}

if [ -n "${ZSH_VERSION:-}" ]; then
  _upd_report() {
    [ -n "${UPD_SUMMARY:-}" ] || return 0
    printf 'upd: failed: %s\n' "$UPD_SUMMARY" >&2
    unset UPD_SUMMARY
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _upd_report
fi

zcomp-update() {
  local _zc_dir="$HOME/.zsh_completions.d"
  local _zc_brew _zc_sf="" _zc_tool _zc_args _zc_tmp _zc_restart=1
  case "${1:-}" in
    "") ;;
    --no-restart) _zc_restart=0 ;;
    *) echo "usage: zcomp-update [--no-restart]" >&2; return 2 ;;
  esac
  _zc_brew=$(command -v brew 2>/dev/null)
  [ -n "$_zc_brew" ] && _zc_sf="$(dirname "$(dirname "$_zc_brew")")/share/zsh/site-functions"
  for _zc_tool in opencode gh glab acli docker asdf glow git-lfs bun starship tv procs bat uv uvx ruff rg fd; do
    command -v "$_zc_tool" >/dev/null 2>&1 || continue
    if [ -n "$_zc_sf" ] && [ -e "$_zc_sf/_$_zc_tool" ]; then
      continue
    fi
    _zc_args=$(_zcomp_gen_cmd "$_zc_tool")
    _zc_tmp=$(mktemp) || return 1
    # eval so the argument string word-splits identically in bash and zsh
    if eval "\"\$_zc_tool\" $_zc_args" >"$_zc_tmp" 2>/dev/null && [ -s "$_zc_tmp" ]; then
      mv "$_zc_tmp" "$_zc_dir/_$_zc_tool" && echo "zcomp-update: $_zc_tool: updated"
    else
      rm -f "$_zc_tmp"
      echo "zcomp-update: $_zc_tool: generator failed, skipping" >&2
    fi
  done
  if [ -n "${ZSH_VERSION:-}" ] && command -v zcomp-rebuild >/dev/null 2>&1; then
    zcomp-rebuild
  else
    rm -f "$HOME/.zcompdump" "$HOME/.zcompdump.zwc"
  fi
  if [ "$_zc_restart" = 1 ]; then
    _upd_restart_shell
    echo "zcomp-update: run 'exec zsh' to load the new completions"
  fi
}

upd() {
  local _failed="" _cmd _restart=1
  case "${1:-}" in
    "") ;;
    --no-restart) _restart=0 ;;
    *) echo "usage: upd [--no-restart]" >&2; return 2 ;;
  esac
  local _cmds=("brew update" "brew upgrade -y" "claude --update")
  command -v openchamber >/dev/null && _cmds+=("openchamber update")
  _cmds+=(
    "DISABLE_TELEMETRY=1 npx --yes skills@latest update -g -y"
    "claude_update_all_plugins"
    "opencode plugin update"
    "zcomp-update --no-restart"
  )
  for _cmd in "${_cmds[@]}"; do
    echo '################################################################################'
    echo "... $_cmd..."
    echo '--------------------------------------------------------------------------------'
    eval "$_cmd" || _failed="${_failed:+$_failed, }$_cmd"
    echo '--------------------------------------------------------------------------------'
    echo ""
  done
  if [ "$_restart" = 1 ]; then
    _upd_restart_shell "$_failed"
    echo "upd: run 'exec zsh' to load the new completions"
  fi
  if [ -n "$_failed" ]; then
    echo "upd: failed: $_failed" >&2
    return 1
  fi
}
alias ccupd="claude --update"
alias bupd="brew update && brew upgrade -y"
alias sk="DISABLE_TELEMETRY=1 npx --yes skills@latest"
alias yupd="DISABLE_TELEMETRY=1 npx --yes skills@latest update -g -y"
alias opupd="openchamber update"
alias ccuap="claude_update_all_plugins"

