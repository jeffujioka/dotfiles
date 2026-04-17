#!/usr/bin/bash

# FIND PROCESS
function p() {
    pgrep -lif "$1"
}

function print_info() {
    cnt=$(pgrep -cif "$1")

    echo -e "\nSearching for '$1' -- Found $cnt Running Processes .."
    p "$1"

    echo -e "\nTerminating $cnt processes .."
}

function print_alive_processes() {
    cnt=$(pgrep -cif "$1")
    if (( $cnt > 0 )); then
        echo -e "\nThere is/are '$cnt' process[es] still running...\n"
        p "$1"
    fi
}

# KILL ALL
function ka() {
    if [ -z "$2" ]; then
        klevel=15
    else
        klevel=$2
    fi

    print_info "$1"

    if (( $cnt > 0 )); then
        pkill -"$klevel" -if "$1"

        print_alive_processes "$1"
    else
        echo -e "No '$1' process found.\n"
    fi
}

# SUDO KILL ALL
function ska() {
    if [ -z "$2" ]; then
        klevel=15
    else
        klevel=$2
    fi

    print_info "$1"

    if (( $cnt > 0 )); then
        sudo pkill -"$klevel" -if "$1"

        print_alive_processes "$1"
    else
        echo -e "No '$1' process found.\n"
    fi
}

function cdmkdir() {
    if [ -z "$1" ]; then
        echo "empty dir... exiting..."
        return 1
    fi

    local dir="$1"
    mkdir -p "$dir"
    cd "$dir"
}
alias mkcd="cdmkdir"

function f() {
    if ! command -v fzf &> /dev/null; then
        echo "Error: fzf is not installed"
        return 1
    fi

    if [ $# -eq 0 ]; then
        fzf
    else
        local search_path="${@: -1}"  # Get the last argument
        if [ ! -d "$search_path" ]; then
            echo "Error: Last argument is not a valid directory"
            return 1
        fi
        pushd "$search_path" &> /dev/null
        fzf "${@:1:$#-1}"  # Forward all arguments except the last one
        popd &> /dev/null
    fi
}

function fq() {
    if [ $# -lt 2 ]; then
        echo "Error: fq requires at least two arguments: <query> <directory path>"
        return 1
    fi

    search_dir="${@: -1}"
    query="${@: -2:1}"
    opts="${@:1:$#-2}"

    f $opts -q $query $search_dir
}

function fqi() {
    if [ $# -eq 0 ]; then
        echo "Error: fqi requires at least two arguments: <query> <directory path>"
        return 1
    fi

    if [ $# -eq 1 ]; then
        f -i -q "$1" .
    else
        search_dir="${@: -1}"
        query="${@: -2:1}"
        opts="${@:1:$#-2}"

        f $opts -i -q $query $search_dir
    fi
}

##
## Basic aliases
##
################################################################################

# Use eza instead of ls (modern replacement for exa)
EZA_DEFAULT="--icons --group-directories-first"
alias ls="eza $EZA_DEFAULT"
alias ll="eza -l $EZA_DEFAULT"
alias lla="eza -la $EZA_DEFAULT"
alias llt="eza -lT $EZA_DEFAULT"
alias llta="eza -lTa $EZA_DEFAULT"
alias tree="eza -T $EZA_DEFAULT"
alias treel="eza -lT $EZA_DEFAULT"
alias treela="eza -lTa $EZA_DEFAULT"

if command -v pbcopy &> /dev/null; then
  alias pp="pbcopy"
fi

if command -v pbpaste &> /dev/null; then
  alias ppe="pbpaste"
fi

# FZF
alias fprv="fzf --preview 'bat --color=always --style=numbers {}'"

# Conservative file operations
#alias rm='rm -i'
#alias mv='mv -i'
#alias cp='cp -i'
alias rmf="rm -rf"
alias cpr="cp -R"

alias mkdir="mkdir -p"

# List hidden files
alias l.='eza -d .*'

# Change directory
alias cd..='cd ..'
alias ..='cd ..'
alias ..2='cd ../..'
alias ..3='cd ../../..'
alias ..4='cd ../../../..'
alias ..5='cd ../../../../..'
alias ..6='cd ../../../../../..'
alias ..7='cd ../../../../../../..'
alias ..8='cd ../../../../../../../..'
alias ..9='cd ../../../../../../../../..'

##
## AI
##
################################################################################
alias cc="claude"
alias cca="claude --resume --dangerously-skip-permissions"
alias ct="copilot"
alias cta="copilot --allow-all"

##
## Utils
##
################################################################################
alias now='date +"%T"'
alias timestamp='date +%Y%m%d_%H%M%S'
alias path='echo $PATH'
alias path-lines='echo -e ${PATH//:/\\n}'

alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
alias alert-sound='while true; do sleep 1; echo -e -n "\a"; done'
alias alert-test='while true; do beep; sleep 1; done'
alias soundalert=alert-sound
alias alert-done='echo "Done at: $(date)"; alert "Done at: $(date)"; alert-sound'

alias sourcebash-rc="source ~/.bashrc"
alias sourcezsh-rc="source ~/.zshrc"
alias sourcebash-aliases="source ~/.bash_aliases"
alias sourcebash-fns="source ~/.bash_fns"

alias rclear="reset && clear"

alias o="xdg-open"

##
## Common apps
##
################################################################################
alias apt-get='sudo apt-get'
alias vi=vim


##
## sysadmin
##
################################################################################

alias spwd='cat ~/.pwdrc | sudo -S'

# cpu info (older system use /proc/cpuinfo)
alias cpuinfo='lscpu || less /proc/cpuinfo'
alias meminfo='free -m -l -t'
## get GPU ram on desktop / laptop##
alias gpumeminfo='grep -i --color memory /var/log/Xorg.0.log'

# list top process eating memory
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
# list top process eating cpu
alias pscpu='ps auxf | sort -nr -k 3'
alias pscpu10='ps auxf | sort -nr -k 3 | head -10'


export BEEP=/usr/share/sounds/ubuntu/notifications/Positive.ogg
alias beep="paplay --volume=65536 $BEEP"

alias mic-list="pactl list short sources"

alias clear="clear && printf '\e[3J'"

alias sim='sudo vim -S "$HOME/.vimrc"'

##
## keyboard
##
###############################################################################
alias show-keyboard-variants="localectl list-x11-keymap-variants"
alias show-keyboard-us-variants="localectl list-x11-keymap-variants us"
alias show-keyboard-layouts="localectl list-x11-keymap-layouts"
alias kboard2-us="setxkbmap us"
alias kboard2-us-intl="setxkbmap us intl"
alias kboard2-de="setxkbmap de"

alias runedge="microsoft-edge --remote-debugging-port=9222 > /dev/null 2>&1 &"

##
## New utilities
##
################################################################################

function x() {
    if [ -z "$1" ]; then
        echo "Usage: x <file>"
        return 1
    fi

    if [ ! -f "$1" ]; then
        echo "'$1' is not a valid file"
        return 1
    fi

    case "$1" in
        *.tar.bz2) tar xjf "$1"    ;;
        *.tar.gz)  tar xzf "$1"    ;;
        *.tar.xz)  tar xJf "$1"    ;;
        *.bz2)     bunzip2 "$1"    ;;
        *.gz)      gunzip "$1"     ;;
        *.tar)     tar xf "$1"     ;;
        *.tbz2)    tar xjf "$1"    ;;
        *.tgz)     tar xzf "$1"    ;;
        *.zip)     unzip "$1"      ;;
        *.Z)       uncompress "$1" ;;
        *.7z)      7z x "$1"       ;;
        *.rar)     unrar x "$1"    ;;
        *.xz)      unxz "$1"       ;;
        *)         echo "'$1' cannot be extracted via x()" ;;
    esac
}

function serve() {
    local port="${1:-8000}"
    echo "Serving on http://localhost:$port"
    python3 -m http.server "$port"
}

function ports() {
    if [[ "$(uname)" == "Darwin" ]]; then
        lsof -iTCP -sTCP:LISTEN -n -P
    else
        ss -tlnp
    fi
}

alias myip='curl -s ifconfig.me && echo'
