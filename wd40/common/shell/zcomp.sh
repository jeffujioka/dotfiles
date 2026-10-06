#!/usr/bin/env bash
# wd40: zcomp-rebuild - delete the cached zsh completion dump and rebuild it (zsh only)

function zcomp-rebuild() {
    if [ -z "${ZSH_VERSION:-}" ]; then
        echo "zcomp-rebuild: zsh only" >&2
        return 1
    fi
    local dump="${ZDOTDIR:-$HOME}/.zcompdump"
    rm -f "$dump" "$dump.zwc"
    autoload -Uz compinit
    compinit -d "$dump"
    echo "zcomp-rebuild: rebuilt $dump"
}
