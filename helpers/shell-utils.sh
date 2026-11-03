#!/bin/bash
# Shared shell utilities sourced by install.sh and tests/helpers.sh.

resolve_path() {
    # Portable readlink -f: works on both Linux (GNU) and macOS ARM (BSD).
    # Falls back to Python when GNU coreutils are unavailable.
    readlink -f "$1" 2>/dev/null \
        || python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1"
}

brew_installed_names() {
    # Short names of every installed brew formula and cask, one per line.
    # Lets callers detect formulae that ship no binary named after
    # themselves (awscli -> aws, zlib, completions) without a per-package
    # `brew list` round trip.
    brew list --formula -1 2>/dev/null
    brew list --cask -1 2>/dev/null
}
