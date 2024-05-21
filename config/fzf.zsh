# Setup fzf
# ---------
if [[ ! "$PATH" == */lhome/jfujiok/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/lhome/jfujiok/.fzf/bin"
fi

export FD_OPTIONS="--follow --exclude .git --exclude node_modules"
export FZF_GEN_OPTS="--height 50% -1 --reverse --multi --inline-info"
export FZF_PREVIEW_WIN_OPTS="--preview-window='right:wrap'"
export FZF_PREVIEW_COMMAND='([[ $(file --mime-type -b {}) == image/* ]] 2> /dev/null && viu -w 50 -h 20 {}) || bat --style=numbers --color=always --line-range :50 {} 2> /dev/null || cat {} 2> /dev/null || tree -C -L 3 {}'
export FZF_CTRL_R_OPTS="${FZF_CTRL_R_OPTS:+$FZF_CTRL_R_OPTS }--preview 'echo {}' --preview-window down:5:wrap --bind '?:toggle-preview'"
export FZF_PREVIEW_OPTS="--preview '${FZF_PREVIEW_COMMAND}'"
export FZF_BIND_OPTS="--bind='f3:execute(bat --style=numbers {} || less -f {}),f2:toggle-preview,ctrl-d:half-page-up,ctrl-a:select-all+accept,ctrl-y:execute-silent(echo {+} | xsel -i -b)'"
export FZF_DEFAULT_OPTS="${FZF_GEN_OPTS} ${FZF_PREVIEW_OPTS} ${FZF_PREVIEW_WIN_OPTS} ${FZF_BIND_OPTS}"
export FZF_DEFAULT_COMMAND='git ls-files --cached --others --exclude-standard | fd --type f --type l --type d $FD_OPTIONS'
export FZF_COMPLETION_TRIGGER=";;"

eval "$(fzf --zsh)"
