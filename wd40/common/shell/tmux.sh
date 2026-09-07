#!/usr/bin/env bash
# wd40: tmux-update - re-export the current tmux session environment into this shell (alias: tmup)
##
## tmux
##
################################################################################

function tmux-update () { 
    echo "Updating to latest tmux environment...";
    export IFS=",";
    for line in $(tmux showenv -t $(tmux display -p "#S") | tr "\n" ",");
    do
        if [[ $line == -* ]]; then
            echo "$line unset"
            unset $(echo $line | cut -c2-);
        else
            echo "export $line"
            export $line;
        fi;
    done;
#    local ssh_cli=`env | grep SSH_CLIENT`
#    export "$ssh_cli"    
    unset IFS;
    echo "...Done"
}
alias tmup='tmux-update'
