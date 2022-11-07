##
## Basic aliases
##
################################################################################

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
alias soundalert=alert-sound
alias alert-done='echo "Done at: $(date)"; alert "Done at: $(date)"; alert-sound'

alias sourcebash-rc="source ~/.bashrc"
alias sourcebash-aliases="source ~/.bash_aliases"

alias rclear="reset && clear"

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


alias clear="clear && printf '\e[3J'"

alias sudovim='sudo vim -S /lhome/$USER/.vimrc'
