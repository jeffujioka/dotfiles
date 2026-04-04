#!/bin/sh

yes_or_no() {
    printf '%b\n' "$1"

    while true; do
        read -r answer
        case "$answer" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) printf '%s\n' "Please answer y/Y or n/N." ;;
        esac
    done
}
