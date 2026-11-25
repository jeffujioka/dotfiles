# /etc/zsh/zshrc on Ubuntu runs compinit before ~/.zshrc, which writes the
# completion dump without ~/.zsh_completions.d on fpath. ~/.zshrc runs compinit itself.
skip_global_compinit=1

# Node comes from asdf. `ssh host cmd` and `zsh -c` read only this file, so without these two lines `node` is not found
# there; an asdf shim also execs `asdf`, which lives in Homebrew's bin. ~/.zshrc puts the same dirs in front again, and
# `typeset -U` keeps PATH free of duplicates.
if [[ "$OSTYPE" == darwin* ]]; then
  typeset -U path
  path=("$HOME/.asdf/shims" /opt/homebrew/bin $path)
fi
