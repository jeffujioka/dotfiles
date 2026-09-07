#!/usr/bin/env bash
# wd40: basic-linux-aliases - Linux-only aliases (xdg-open, notify-send alerts, lscpu/free, PulseAudio mic, X11 keyboard layouts)

alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
alias alert-sound='while true; do sleep 1; echo -e -n "\a"; done'
alias alert-test='while true; do beep; sleep 1; done'
alias soundalert=alert-sound
alias alert-done='echo "Done at: $(date)"; alert "Done at: $(date)"; alert-sound'

alias o="xdg-open"

alias apt-get='sudo apt-get'

# cpu info (older system use /proc/cpuinfo)
alias cpuinfo='lscpu || less /proc/cpuinfo'
alias meminfo='free -m -l -t'
## get GPU ram on desktop / laptop##
alias gpumeminfo='grep -i --color memory /var/log/Xorg.0.log'

export BEEP=/usr/share/sounds/ubuntu/notifications/Positive.ogg
alias beep="paplay --volume=65536 $BEEP"
alias mic-list="pactl list short sources"

alias show-keyboard-variants="localectl list-x11-keymap-variants"
alias show-keyboard-us-variants="localectl list-x11-keymap-variants us"
alias show-keyboard-layouts="localectl list-x11-keymap-layouts"
alias kboard2-us="setxkbmap us"
alias kboard2-us-intl="setxkbmap us intl"
alias kboard2-de="setxkbmap de"

alias runedge="microsoft-edge --remote-debugging-port=9222 > /dev/null 2>&1 &"
