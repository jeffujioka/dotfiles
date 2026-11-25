# Setup fzf
# ---------
if [[ ! "$PATH" == */lhome/jfujiok/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/lhome/jfujiok/.fzf/bin"
fi

# https://github.com/akinomyoga/ble.sh/issues/296
# don't print error codes
bleopt exec_errexit_mark=

# https://github.com/akinomyoga/ble.sh/issues/41#issuecomment-583868999
# clear blesh completer for cd
blehook/eval-after-load complete 'unset -f ble/cmdinfo/complete:cd'

# patch fzf functions
# ble/function#advice around __fzf_generic_path_completion _fzf_complete.advice
# ble/function#advice around _fzf_complete                 _fzf_complete.advice
# ble/function#advice around _fzf_complete_kill            _fzf_complete.advice
# shellcheck disable=SC2154,SC2016  # comp_* are set by ble.sh's advice machinery, and the printf stub text keeps a literal $1 and $@
function _fzf_complete.advice {
  [[ :$comp_type: == *:auto:* ]] && {
    compopt -o default
    return
  }
  compopt -o noquote
  COMP_WORDS=("${comp_words[@]}") COMP_CWORD=$comp_cword
  COMP_LINE=$comp_line COMP_POINT=$comp_point
  ble/function#push printf '[[ $1 == "\e[5n" ]] || builtin printf "$@"'
  ble/function#advice/do </dev/tty &>/dev/tty
  ble/function#pop printf
  ble/textarea#invalidate
}

export FD_OPTIONS="--follow --exclude .git --exclude node_modules"
export FZF_GEN_OPTS="--height 50% -1 --reverse --multi --inline-info"
export FZF_PREVIEW_WIN_OPTS="--preview-window='right:wrap'"
# shellcheck disable=SC2016  # fzf runs this command through a shell later, so $(...) must stay literal
export FZF_PREVIEW_COMMAND='([[ $(file --mime-type -b {}) == image/* ]] 2> /dev/null && viu -w 50 -h 20 {}) || bat --style=numbers --color=always --line-range :50 {} 2> /dev/null || cat {} 2> /dev/null || tree -C -L 3 {}'
export FZF_CTRL_R_OPTS="${FZF_CTRL_R_OPTS:+$FZF_CTRL_R_OPTS }--preview 'echo {}' --preview-window down:5:wrap --bind '?:toggle-preview'"
export FZF_PREVIEW_OPTS="--preview '${FZF_PREVIEW_COMMAND}'"
export FZF_BIND_OPTS="--bind='f3:execute(bat --style=numbers {} || less -f {}),f2:toggle-preview,ctrl-d:half-page-up,ctrl-a:select-all+accept,ctrl-y:execute-silent(echo {+} | pbcopy)'"
export FZF_DEFAULT_OPTS="${FZF_GEN_OPTS} ${FZF_PREVIEW_OPTS} ${FZF_PREVIEW_WIN_OPTS} ${FZF_BIND_OPTS}"
# shellcheck disable=SC2016  # fzf expands $FD_OPTIONS when it runs the command, so the $ must stay literal
export FZF_DEFAULT_COMMAND='git ls-files --cached --others --exclude-standard | fd --type f --type l --type d $FD_OPTIONS'

eval "$(fzf --bash)"
