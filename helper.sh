#!/bin/sh

yes_or_no() {
    echo -e "$1"
    
    while true; do
        read answer
        case "$answer" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo "Please answer y/Y or n/N." ;;
        esac
    done
}
