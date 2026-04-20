#!/usr/bin/zsh

if [ -z "${XDG_CONFIG_HOME}" ]; then
   export XDG_CONFIG_HOME="$HOME/.config"
fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add in snippets
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::command-not-found
zinit snippet OMZP::jira

# Load completions
fpath=(~/.zsh_completions.d $fpath)
autoload -Uz compinit && compinit

zinit cdreplay -q

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# History
HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
setopt hist_expire_dups_first
setopt hist_find_no_dups
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_save_no_dups

# Completion styling
zstyle ':fzf-tab:*' popup-min-size 80 12
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
# zstyle ':completion:*' menu select
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup

bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# PATH priority (highest → lowest): .local/bin > .scripts > Homebrew > NVM > cargo
# Each block PREPENDs — the LAST one to run ends up at the FRONT of PATH.

# cargo — lowest priority (Rust toolchain, manual use)
CARGO_HOME="${XDG_CONFIG_HOME}/cargo"
CARGO_ENV="${CARGO_HOME}/env"
if [ -f "${CARGO_ENV}" ]; then
  source "${CARGO_ENV}"
elif [ -d "${CARGO_HOME}/bin" ]; then
  if [[ ! "$PATH" == *"${CARGO_HOME}/bin"* ]]; then
    export PATH="${CARGO_HOME}/bin:${PATH}"
  fi
fi

# NVM — above cargo
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Homebrew — above NVM
if [[ "$OSTYPE" == darwin* ]] && [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ "$OSTYPE" == linux* ]] && [[ -x "$HOME/.homebrew/bin/brew" ]]; then
  eval "$($HOME/.homebrew/bin/brew shellenv)"
fi

# .scripts — above Homebrew
if [[ ! "$PATH" == *.scripts* ]]; then
  export PATH="$HOME/.scripts:${PATH:+${PATH}:}"
fi

# .local/bin — highest priority
if [[ ! "$PATH" == *${HOME}/.local/bin* ]]; then
  export PATH="$HOME/.local/bin:${PATH:+${PATH}:}"
fi

if [ -r "${HOME}/.zsh_aliases" ]; then
  . "${HOME}/.zsh_aliases"
fi

export TMUX_TMPDIR="$HOME/.config/tmux/tmp"
mkdir -p "$TMUX_TMPDIR"

unsetopt pathdirs

cat ~/.config/ascii-art-goku.txt

echo "setting up..."

if command -v starship &> /dev/null ; then
  echo "   starship"
  export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/config.toml"
  eval "$(starship init zsh)"
fi

if [[ -L "${XDG_CONFIG_HOME}/fzf/fzf.zsh" || -f "${XDG_CONFIG_HOME}/fzf/fzf.zsh" ]]; then
  echo "   fzf"
  source "${XDG_CONFIG_HOME}/fzf/fzf.zsh"
fi

if command -v tv &> /dev/null ; then
  echo "   television"
  eval "$(tv init zsh)"
fi

if command -v zoxide &> /dev/null ; then
  echo "  󰆤 zoxide"
  eval "$(zoxide init --cmd cd zsh)"
fi

# Keep tmux pane_title meaningful: hostname when idle, command name when running.
# Without this, processes like tmux reset the OSC title to empty and pane borders
# show nothing instead of the current command.
autoload -Uz add-zsh-hook
_set_title_precmd()  { printf '\e]0;%s\a' "$HOST" }
_set_title_preexec() { printf '\e]0;%s\a' "${1%% *}" }
add-zsh-hook precmd  _set_title_precmd
add-zsh-hook preexec _set_title_preexec
