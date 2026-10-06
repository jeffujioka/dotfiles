#!/usr/bin/bash
# wd40: p - find processes matching a pattern (pgrep -lif)
# wd40: print_info - print the count and list of processes matching a pattern
# wd40: print_alive_processes - report processes still alive after a kill
# wd40: ka - kill all processes matching a pattern (optional signal level)
# wd40: ska - sudo kill all processes matching a pattern (optional signal level)
# wd40: mkcd - mkdir -p a directory and cd into it
# wd40: f - fzf wrapper that can search inside a given directory
# wd40: fq - f with a query: fq [OPTS] QUERY DIR
# wd40: fqi - case-insensitive fq; a single arg searches the current directory
# wd40: x - extract any archive by extension
# wd40: serve - serve the current directory over HTTP (default port 8000)
# wd40: ports - list listening TCP ports (lsof on macOS, ss elsewhere)
# wd40: basic-aliases - eza listings, cd shortcuts, AI CLI shorthands, misc utils

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

function mkcd() {
    if [ -z "$1" ]; then
        echo "empty dir... exiting..."
        return 1
    fi

    local dir="$1"
    mkdir -p "$dir"
    cd "$dir"
}

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
alias cca="claude --dangerously-skip-permissions"
alias ccar="claude --dangerously-skip-permissions --resume"
alias ct="copilot"
alias cta="copilot --allow-all"
alias oc="opencode --auto"

##
## Utils
##
################################################################################
alias rc='remote-code'
alias rcl='remote-code --local'

alias now='date +"%T"'
alias timestamp='date +%Y%m%d_%H%M%S'
alias path='echo $PATH'
alias path-lines='echo -e ${PATH//:/\\n}'


alias sourcebash-rc="source ~/.bashrc"
alias sourcezsh-rc="source ~/.zshrc"
alias sourcebash-aliases="source ~/.bash_aliases"
alias sourcebash-fns="source ~/.bash_fns"

alias rclear="reset && clear"


##
## Common apps
##
################################################################################
alias vi=vim


##
## sysadmin
##
################################################################################

alias spwd='cat ~/.pwdrc | sudo -S'


# list top process eating memory
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
# list top process eating cpu
alias pscpu='ps auxf | sort -nr -k 3'
alias pscpu10='ps auxf | sort -nr -k 3 | head -10'



alias clear="clear && printf '\e[3J'"

alias sim='sudo vim -S "$HOME/.vimrc"'

##
## keyboard
##
###############################################################################


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
