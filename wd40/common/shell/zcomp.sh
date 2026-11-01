#!/usr/bin/env bash
# wd40: zcomp_rebuild - delete the cached zsh completion dump and rebuild it (zsh only)

function zcomp_rebuild() {
    if [ -z "${ZSH_VERSION:-}" ]; then
        echo "zcomp_rebuild: zsh only" >&2
        return 1
    fi
    local dump="${ZDOTDIR:-$HOME}/.zcompdump"
    rm -f "$dump" "$dump.zwc"
    autoload -Uz compinit
    compinit -d "$dump"
    echo "zcomp_rebuild: rebuilt $dump"
}
