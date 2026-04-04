#!/bin/bash
# Shared shell utilities sourced by install.sh and tests/helpers.sh.

resolve_path() {
    # Portable readlink -f: works on both Linux (GNU) and macOS ARM (BSD).
    # Falls back to Python when GNU coreutils are unavailable.
    readlink -f "$1" 2>/dev/null \
        || python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1"
}
