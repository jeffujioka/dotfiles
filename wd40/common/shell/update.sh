#!/bin/env bash
# wd40: upd - update brew, Claude Code, OpenChamber, litellm, skills, plugins, and zsh completions, then restart zsh (--no-restart to skip)
# wd40: zcomp_update - regenerate zsh completion scripts for installed CLIs and rebuild the dump, then restart zsh (--no-restart to skip)
# wd40: skills_install_or_update - install missing and update my agent skills (global, every agent)
# wd40: plugins_install_or_update - install missing and update my claude and omp plugins and marketplaces

claude_update_all_plugins() (
  json=$(claude plugin list --json) || exit $?
  # Session-scoped plugins (e.g. orca-agent-view@inline, injected via --plugin-dir) are not installed.
  names=$(printf '%s\n' "$json" | jq -r '.[] | select(.scope != "session") | .id | split("@")[0]') || exit $?
  [ -n "$names" ] || exit 0

  rc=0
  while IFS= read -r plugin; do
    claude plugin update "$plugin" || rc=1
  done <<EOF
$names
EOF
  exit "$rc"
)

# --- skills and plugins I use most: install what is missing, update the rest ---
# Sourced into interactive bash and zsh: no `set` options, no zsh-only syntax.
# A failing step never aborts the run: it is appended to the comma-separated
# _iou_failed list (via _iou_run or _iou_record_failure) and the next
# step still runs. _iou_finish then reports the list and returns 1.
# Each public function resets _iou_failed on entry.
_iou_failed=""

_iou_record_failure() { # DESCRIPTION
  _iou_failed="${_iou_failed}${_iou_failed:+, }$1"
}

# Print "+ CMD ARG...", run it, and on a non-zero exit record it in _iou_failed.
# Returns the command's success (0) or 1 on failure; callers ignore it.
_iou_run() { # CMD [ARG...]
  echo "+ $*"
  "$@" || {
    _iou_record_failure "$*"
    return 1
  }
}

# The `skills` CLI with telemetry off (aliases do not expand inside functions).
_iou_sk() {
  DISABLE_TELEMETRY=1 npx --yes skills@latest "$@"
}

_iou_finish() { # NAME
  [ -z "$_iou_failed" ] && return 0
  echo "$1: failed: $_iou_failed" >&2
  return 1
}

# `skills add` on an installed skill refreshes it, so one run reaches the latest.
skills_install_or_update() {
  _iou_failed=""
  if ! command -v npx >/dev/null 2>&1; then
    echo "skills_install_or_update: npx not found" >&2
    return 1
  fi
  _iou_run _iou_sk add anthropics/skills -s pptx docx pdf xlsx changelog-generator -g -y -a universal
  _iou_run _iou_sk add jeffujioka/skills -s '*' -g -y -a universal
  _iou_run _iou_sk add mattpocock/skills -s '*' -g -y -a universal
  _iou_run _iou_sk add vercel-labs/agent-browser -s agent-browser vercel-react-best-practices -g -y -a universal
  _iou_run _iou_sk add voicestudiohq/voicestudio -s voicestudio-cli -g -y -a universal
  _iou_run _iou_sk add herdrdev/herdr-core -s herdr-core -g -y -a universal
  _iou_run _iou_sk add stablyai/orca -s 'orchestration' -s 'orca-cli' -s 'orca-computer-use' -s 'orca-plugin-authoring' -g -y -a universal
  _iou_run _iou_sk add github/awesome-copilot -s 'excalidraw-diagram-generator' -g -y -a universal
  _iou_finish skills_install_or_update
}

# Marketplace sources and plugins (PLUGIN@MARKETPLACE) I use, one per line.
# A marketplace's name is the last part of its source.
_IOU_MARKETPLACES="obsidianmd/obsidian-skills
lackeyjb/playwright-skill
obra/superpowers-marketplace"
_IOU_PLUGINS="obsidian@obsidian-skills
playwright-skill@playwright-skill
superpowers@superpowers-marketplace"

_iou_foreach() { # LIST CMD [ARG...]: run CMD ARG... ITEM for each line of LIST
  local list=$1 item
  shift
  while IFS= read -r item; do
    "$@" "$item"
  done <<EOF
$list
EOF
}

# claude's marketplace add and plugin install succeed when already present; omp's
# exit 1, so omp only adds what is missing.
_iou_omp_add_marketplace() { # SOURCE
  if omp plugin marketplace 2>&1 | grep -q "^  ${1##*/} "; then
    echo "omp marketplace ${1##*/} already added"
  else
    _iou_run omp plugin marketplace add "$1"
  fi
}

_iou_omp_install() { # PLUGIN@MARKETPLACE
  if omp plugin list 2>&1 | grep -q "^  $1 "; then
    echo "omp plugin $1 already installed"
  else
    _iou_run omp plugin install "$1"
  fi
}

# Run `npm run setup` in the newest playwright-skill dir under ROOT when the
# plugin changed (BEFORE != AFTER) or has no node_modules yet.
_iou_playwright_setup() { # BEFORE AFTER ROOT PATH_PATTERN
  local dir
  dir=$(find "$3" -maxdepth 4 -type d -path "$4" 2>/dev/null | sort | tail -n 1)
  if [ -z "$dir" ]; then
    echo "plugins_install_or_update: playwright-skill dir not found under $3, skipping npm run setup" >&2
  elif [ "$1" != "$2" ] || [ ! -d "$dir/node_modules" ]; then
    echo "+ npm run setup ($dir)"
    (cd "$dir" && npm run setup) || _iou_record_failure "npm run setup ($dir)"
  fi
}

# Neither CLI's install updates an installed plugin, hence the explicit update
# steps. A missing CLI is skipped.
plugins_install_or_update() {
  local pw_before pw_after
  _iou_failed=""

  if command -v claude >/dev/null 2>&1; then
    pw_before=$(claude plugin list 2>&1 | grep -A1 "playwright-skill@")
    _iou_foreach "$_IOU_MARKETPLACES" _iou_run claude plugin marketplace add
    _iou_run claude plugin marketplace update
    _iou_foreach "$_IOU_PLUGINS" _iou_run claude plugin install
    _iou_foreach "$_IOU_PLUGINS" _iou_run claude plugin update
    pw_after=$(claude plugin list 2>&1 | grep -A1 "playwright-skill@")
    _iou_playwright_setup "$pw_before" "$pw_after" "$HOME/.claude/plugins/cache/playwright-skill" '*/skills/playwright-skill'
  else
    echo "plugins_install_or_update: claude not found, skipping" >&2
  fi

  if command -v omp >/dev/null 2>&1; then
    pw_before=$(omp plugin list 2>&1 | grep "^  playwright-skill@")
    _iou_foreach "$_IOU_MARKETPLACES" _iou_omp_add_marketplace
    _iou_run omp plugin marketplace update
    _iou_foreach "$_IOU_PLUGINS" _iou_omp_install
    _iou_run omp plugin upgrade
    pw_after=$(omp plugin list 2>&1 | grep "^  playwright-skill@")
    _iou_playwright_setup "$pw_before" "$pw_after" "$HOME/.omp/plugins/cache/plugins" '*playwright-skill___playwright-skill___*/skills/playwright-skill'
  else
    echo "plugins_install_or_update: omp not found, skipping" >&2
  fi

  _iou_finish plugins_install_or_update
}

# Path of the machine-local update script (gitignored), found through the
# ~/.config/wd40/wd40rc link the installer makes. Prints nothing when absent.
_upd_local_script() {
  local rc f
  rc=$(readlink "$HOME/.config/wd40/wd40rc") || return 0
  f="$(dirname "$rc")/local/scripts/update.sh"
  [ -f "$f" ] && printf '%s\n' "$f"
  return 0
}

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

zcomp_update() {
  local _zc_dir="$HOME/.zsh_completions.d"
  local _zc_brew _zc_sf="" _zc_tool _zc_args _zc_tmp _zc_restart=1
  case "${1:-}" in
    "") ;;
    --no-restart) _zc_restart=0 ;;
    *) echo "usage: zcomp_update [--no-restart]" >&2; return 2 ;;
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
      mv "$_zc_tmp" "$_zc_dir/_$_zc_tool" && echo "zcomp_update: $_zc_tool: updated"
    else
      rm -f "$_zc_tmp"
      echo "zcomp_update: $_zc_tool: generator failed, skipping" >&2
    fi
  done
  if [ -n "${ZSH_VERSION:-}" ] && command -v zcomp_rebuild >/dev/null 2>&1; then
    zcomp_rebuild
  else
    rm -f "$HOME/.zcompdump" "$HOME/.zcompdump.zwc"
  fi
  if [ "$_zc_restart" = 1 ]; then
    _upd_restart_shell
    echo "zcomp_update: run 'exec zsh' to load the new completions"
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
  command -v uv >/dev/null && uv tool list 2>/dev/null | grep -q '^litellm ' && _cmds+=("uv tool upgrade litellm")
  _cmds+=(
    "asdf-update --weekly"
    "DISABLE_TELEMETRY=1 npx --yes skills@latest update -g -y"
    "claude_update_all_plugins"
    "skills_install_or_update"
    "plugins_install_or_update"
    "opencode plugin update"
    "zcomp_update --no-restart"
  )
  local _local
  _local=$(_upd_local_script)
  [ -n "$_local" ] && _cmds+=("bash '$_local'")
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
alias litellmupdate="uv tool upgrade litellm"
alias ccuap="claude_update_all_plugins"
alias zupd="zcomp_update"

