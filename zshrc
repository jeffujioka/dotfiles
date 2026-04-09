#!/usr/bin/zsh

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"


if [ -z "${XDG_CONFIG_HOME}" ]; then
   export XDG_CONFIG_HOME="$HOME/.config"
fi

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in Powerlevel10k
# zinit ice depth=1; zinit light romkatv/powerlevel10k

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
autoload -Uz compinit && compinit

zinit cdreplay -q

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

cat ~/.config/ascii-art-goku.txt

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# History
HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
# setopt sharehistory
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt hist_find_no_dups
setopt hist_ignore_all_dups
setopt hist_ignore_dups
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

if [ -r "${HOME}/.zsh_completions" ]; then
  . "${HOME}/.zsh_completions"
fi




unsetopt pathdirs

echo "setting up..."

if command -v starship &> /dev/null ; then
  echo "   starship"
  export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/config.toml"
  eval "$(starship init zsh)"
fi

if [[ -L "${XDG_CONFIG_HOME}/fzf/fzf.zsh" || -f "${XDG_CONFIG_HOME}/fzf/fzf.zsh" ]]; then
  echo "  󰮗 fzf"
  source "${XDG_CONFIG_HOME}/fzf/fzf.zsh"
fi




if command -v zoxide &> /dev/null ; then
  echo "  󰰸 zoxide"
  eval "$(zoxide init --cmd cd zsh)"
fi
