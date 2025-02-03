#!/usr/bin/bash

# FIND PROCESS
function p() {
        ps aux | grep -i $1 | grep -v grep
}

function print_info() {
    cnt=$( p $1 | wc -l)  # total count of processes found

    echo -e "\nSearching for '$1' -- Found" $cnt "Running Processes .. "
    p $1

    echo -e '\nTerminating' $cnt 'processes ..'
}

function print_alive_processes() {
    cnt=$( p $1 | wc -l)
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

    print_info $1

    if (( $cnt > 0 )); then
        echo 'kill' -$klevel $(ps aux  |  grep -i $1 |  grep -v grep   | awk '{print $2}')
        ps aux  |  grep -i $1 |  grep -v grep   | awk '{print $2}' | xargs kill -$klevel

        print_alive_processes $1
    else
        echo -e "No '$1' process found.\n"
    fi
}

# KILL ALL
function ska() {
    if [ -z "$2" ]; then
        klevel=15
    else
        klevel=$2
    fi

    if (( $cnt > 0 )); then
        echo 'sudo kill' -$klevel $(ps aux  |  grep -i $1 |  grep -v grep   | awk '{print $2}')
        ps aux  |  grep -i $1 |  grep -v grep   | awk '{print $2}' | xargs sudo kill -$klevel

        print_alive_processes $1
    else
        echo -e "No '$1' process found.\n"
    fi
}

function cdmkdir() {
    if [ -z "$1" ]; then
        echo "empty dir... exiting..."
        exit 1
    fi

    local dir=$1
    mkdir -p $dir
    cd $dir
}

function f() {
    if ! command -v fzf &> /dev/null; then
        echo "Error: fzf is not installed"
        exit 1
    fi

    if [ $# -eq 0 ]; then
        # echo "searching files under: $PWD"
        fzf
    else
        local search_path="${@: -1}"  # Get the last argument
        if [ ! -d "$search_path" ]; then
            echo "Error: Last argument is not a valid directory"
            exit 1
        fi
        pushd "$search_path" &> /dev/null
        # echo "searching files under: $PWD"
        fzf "${@:1:$#-1}"  # Forward all arguments except the last one
        popd &> /dev/null
    fi
}

function fq() {
    if [ $# -lt 2 ]; then
        echo "Error: fq requires at least two arguments: <query> <directory path>"
        exit 1
    fi

    if [ $# -eq 1 ]; then
        f $opts -q $query .
    else
        search_dir="${@: -1}"
        query="${@: -2:1}"
        opts="${@:1:$#-2}"

        # echo "last: ${search_dir}"
        # echo "query: ${query}"
        # echo "opts: ${opts}"

        f $opts -q $query $search_dir
    fi
}

function fqi() {
    if [ $# -eq 0 ]; then
        echo "Error: fqi requires at least two arguments: <query> <directory path>"
        exit 1
    fi

    if [ $# -eq 1 ]; then
        f $opts -i -q $1 .
    else
        search_dir="${@: -1}"
        query="${@: -2:1}"
        opts="${@:1:$#-2}"

        # echo "last: ${search_dir}"
        # echo "query: ${query}"
        # echo "opts: ${opts}"

        f $opts -i -q $query $search_dir
    fi
}

##
## Basic aliases
##
################################################################################

# Use exa instead of ls
alias ls="exa"
alias ll="exa -l"
alias lla="exa -la"
alias tree="exa -T"
alias treel="exa -Tl"

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
alias l.='ls -d .* --color=auto'

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

alias sudovim='sudo vim -S /lhome/$USER/.vimrc'

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
