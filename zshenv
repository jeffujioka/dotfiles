# /etc/zsh/zshrc on Ubuntu runs compinit before ~/.zshrc, which writes the
# completion dump without ~/.zsh_completions.d on fpath. ~/.zshrc runs compinit itself.
skip_global_compinit=1
