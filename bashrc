# ~/.bashrc — mirrors ~/.zshrc for bash.
#
# Layout:
#   1. Environment and PATH, for EVERY bash, interactive or not. Non-interactive
#      bash (ssh commands, herdr-core started over ssh) reads this file and
#      stops at the interactive guard, so anything it needs must sit above it.
#   2. Interactive guard.
#   3. exec zsh: no sudo for chsh, so zsh becomes the default shell from here.
#   4. Interactive bash only (DISABLE_ZSH set or stdout not a tty): the bash
#      equivalent of zshrc's interactive setup.

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"

# _path_prepend DIR... — put DIRs at the front of PATH, in the given order,
# dropping any other copy. Same effect as zshrc's `path=(DIR... $path)` under
# `typeset -U path`: a guard that skips dirs already present would leave them
# behind system dirs (path_helper on macOS login shells), so always move.
_path_prepend() {
  local i dir p
  for (( i = $#; i >= 1; i-- )); do
    dir=${!i}
    p=":${PATH}:"
    while [[ $p == *":${dir}:"* ]]; do p=${p//":${dir}:"/:}; done
    p=${p#:}; p=${p%:}
    PATH="${dir}${p:+:$p}"
  done
  export PATH
}

# PATH priority (highest → lowest): .local/bin > .scripts > asdf shims > Homebrew > cargo
# Each block PREPENDs — the LAST one to run ends up at the FRONT of PATH.

# cargo — lowest priority (Rust toolchain, manual use)
CARGO_HOME="${XDG_CONFIG_HOME}/cargo"
CARGO_ENV="${CARGO_HOME}/env"
if [ -f "${CARGO_ENV}" ]; then
  source "${CARGO_ENV}"
elif [ -d "${CARGO_HOME}/bin" ]; then
  _path_prepend "${CARGO_HOME}/bin"
fi

# Homebrew. Static equivalent of `brew shellenv` (saves a fork).
if [[ "$OSTYPE" == darwin* ]] && [[ -x /opt/homebrew/bin/brew ]]; then
  export HOMEBREW_PREFIX="/opt/homebrew"
elif [[ "$OSTYPE" == linux* ]] && [[ -x "$HOME/.homebrew/bin/brew" ]]; then
  export HOMEBREW_PREFIX="$HOME/.homebrew"
fi
if [[ -n $HOMEBREW_PREFIX ]]; then
  export HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
  export HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX"
  _path_prepend "$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin"
  [[ -n ${MANPATH-} ]] && export MANPATH=":${MANPATH#:}"
  export INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH:-}"
fi

# VIMRUNTIME — fix for user homebrew vim compiled with system linuxbrew fallback path
if [[ -d "$HOME/.homebrew/share/vim/vim92" ]]; then
  export VIMRUNTIME="$HOME/.homebrew/share/vim/vim92"
fi

# Homebrew glibc locale data (needed for tmux 3.6a+)
if [[ -d "$HOME/.homebrew/Cellar/glibc/2.39/lib/locale" ]]; then
  export LOCPATH="$HOME/.homebrew/Cellar/glibc/2.39/lib/locale"
fi

# Go — toolchain and `go install` binaries, above Homebrew
export GO_ROOTDIR="$HOME/.local/share/go"
[[ -d "$GO_ROOTDIR/bin" ]] && _path_prepend "$GO_ROOTDIR/bin"
[[ -d "$HOME/go/bin" ]] && _path_prepend "$HOME/go/bin"

# Graphviz for PlantUML (user-local install)
[[ -x "$HOME/.local/bin/dot" ]] && export GRAPHVIZ_DOT="$HOME/.local/bin/dot"

# .scripts — above Homebrew
_path_prepend "$HOME/.scripts"

# .asdf shims — above .scripts
_path_prepend "$HOME/.asdf/shims"

# .local/sbin + .local/bin — always first in PATH.
_path_prepend "${HOME}/.local/sbin" "${HOME}/.local/bin" "${HOME}/.bun/bin"

# TMPDIR, HOMEBREW_TEMP, JAVA_TOOL_OPTIONS → zprofile
# (sourced at login by both bash and zsh so daemons inherit them)
if [ -z "$TMPDIR" ] && [ -r "$HOME/.zprofile" ]; then
  source "$HOME/.zprofile"
fi

export KUBECONFIG="$HOME/.kube/config"

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# fnm
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  _path_prepend "$FNM_PATH"
  eval "$(fnm env --shell bash)"
fi

export EDITOR=vim

# If not running interactively, don't do anything more
case $- in
  *i*) ;;
  *) return ;;
esac

# zsh as the default shell without chsh (no sudo): replace an interactive
# terminal bash with zsh. DISABLE_ZSH=1 bash keeps bash.
if [ -t 1 ] && [ -z "$DISABLE_ZSH" ]; then
  exec zsh
fi

# ---- interactive bash only ------------------------------------------------

[[ -r "${HOME}/.local/share/blesh/ble.sh" ]] && source "${HOME}/.local/share/blesh/ble.sh" --noattach

# History — bash counterparts of zshrc's setopt hist_* options.
export HISTCONTROL=ignoreboth:erasedups
HISTFILESIZE=5000
HISTSIZE=${HISTFILESIZE}
shopt -s histappend
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
  test -r "${HOME}/.dircolors" && eval "$(dircolors -b "${HOME}/.dircolors")" || eval "$(dircolors -b)"
  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi
alias ll='ls -laFh'
alias la='ls -a'
alias l='ls -F'
alias jira="jira-dc"

[ -f "${HOME}/.bash_aliases" ] && . "${HOME}/.bash_aliases"

# programmable completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

if [ -d "${HOME}/.bashrc.d" ]; then
  for rc in "${HOME}"/.bashrc.d/*.sh; do
    [ -x "$rc" ] && . "$rc"
  done
  unset rc
fi

# turn off "suspend/resume" feature
stty -ixon 2>/dev/null

# Secrets (API tokens, etc.) live outside this repo, in ~/.zsh_secrets,
# so they never end up in a public dotfiles history. sourced only if present.
if [ -r "$HOME/.zsh_secrets" ]; then
  source "$HOME/.zsh_secrets"
fi

# Keep the terminal title meaningful: shell name when idle, command name when running.
_set_title_precmd()  { printf '\e]0;%s\a' "${SHELL##*/}"; }
_set_title_preexec() { printf '\e]0;%s\a' "${1%% *}"; }
if [[ ${BLE_VERSION-} ]]; then
  blehook PRECMD+=_set_title_precmd
  blehook PREEXEC+=_set_title_preexec
else
  # PROMPT_COMMAND arms the DEBUG trap; the first command after a prompt fires it once.
  _title_armed=
  _title_precmd() { _set_title_precmd; _title_armed=1; }
  _title_debug()  { [[ -n $_title_armed ]] || return 0; _title_armed=; _set_title_preexec "$BASH_COMMAND"; }
  PROMPT_COMMAND="${PROMPT_COMMAND:+${PROMPT_COMMAND%;};}_title_precmd"
  trap '_title_debug' DEBUG
fi

cat "${XDG_CONFIG_HOME}/ascii-art-goku.txt" 2>/dev/null

echo "setting up..."

if command -v starship &> /dev/null ; then
  echo "   starship"
  export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/config.toml"
  eval "$(starship init bash)"
fi

if [[ -L "${XDG_CONFIG_HOME}/fzf/fzf.bash" || -f "${XDG_CONFIG_HOME}/fzf/fzf.bash" ]]; then
  echo "   fzf"
  source "${XDG_CONFIG_HOME}/fzf/fzf.bash"
fi

if command -v tv &> /dev/null ; then
  echo "   television"
  eval "$(tv init bash)"
fi

if command -v zoxide &> /dev/null ; then
  echo "  󰆤 zoxide"
  eval "$(zoxide init --cmd cd bash)"
fi

# added by wd40 install.sh
if [ -r "$HOME/.config/wd40/wd40rc" ]; then
  . "$HOME/.config/wd40/wd40rc"
fi

[[ ${BLE_VERSION-} ]] && ble-attach
