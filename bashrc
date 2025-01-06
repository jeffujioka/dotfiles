[[ $- == *i* ]] && source ${HOME}/.local/share/blesh/ble.sh --noattach

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
export HISTCONTROL=ignoredups:erasedups

# append to the history file, don't overwrite it
shopt -s histappend

# How many commands can be stored in a file
HISTFILESIZE=5000
# how many commands of the current session can be stored in the memory,
HISTSIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ${HOME}/.dircolors && eval "$(dircolors -b ${HOME}/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -laFh'
alias la='ls -a'
alias l='ls -F'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

if [ -f "${HOME}/.bash_aliases" ]; then
    . "${HOME}/.bash_aliases"
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

if [ -d "${HOME}/.bashrc.d" ]; then
  for rc in "${HOME}"/.bashrc.d/*.sh; do
    if [ -x "$rc" ]; then
      #echo "Reading bashrc file: $rc"
      . $rc
    fi
  done
  unset rc
fi

if [[ ! "$PATH" == *${HOME}/.local/bin* ]]; then
  export PATH="$HOME/.local/bin:${PATH:+${PATH}:}"
fi
if [[ ! "$PATH" == *.scripts* ]]; then
  export PATH="$HOME/.scripts:${PATH:+${PATH}:}"
fi

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"

# turn off "suspend/resume" feature
stty -ixon

export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# if ps -o 'cmd=' -p $(ps -o 'ppid=' -p $$) | grep -vq warp && [ -x /usr/bin/zsh ] && [ "$SHELL" != "/usr/bin/zsh" ]; then
#   export SHELL="/usr/bin/zsh"
#   exec /usr/bin/zsh -l    # -l: login shell again
# fi

# neofetch --ascii_distro Linux
# neofetch --ascii ~/.config/neofetch/ascii-art-goku.txt --ascii_colors 7 2 5 2 3
cat ~/.config/ascii-art-goku.txt 

echo "setting up..."

if command -v starship &> /dev/null ; then
  echo "   starship"
  export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship.toml"
  eval "$(starship init bash)"
fi

if command -v zoxide &> /dev/null ; then
  echo "  󰰸 zoxide"
  eval "$(zoxide init --cmd j bash)"
fi

if [ -f "${XDG_CONFIG_HOME}/fzf.bash" ]; then
  echo "  󰮗 fzf"
  source "${XDG_CONFIG_HOME}/fzf.bash"
fi

if [ -f "${XDG_CONFIG_HOME}/cargo/env" ]; then
  echo "  󱣘 cargo"
  source "${XDG_CONFIG_HOME}/cargo/env"
fi

if [ -f "${HOME}/.bash_completion/alacritty" ]; then
  echo "   alacrity"
  source "${HOME}/.bash_completion/alacritty"
fi

# if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
#   exec tmux
# fi

if [ -f "${HOME}/.bash_completion/tmux_completion" ]; then
  echo "   tmux autocomplete"
  source "${HOME}/.bash_completion/tmux_completion"
fi

[[ ${BLE_VERSION-} ]] && ble-attach
