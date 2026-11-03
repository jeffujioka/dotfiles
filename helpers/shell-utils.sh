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

# Platform vocabulary for manifest `platform` fields: darwin | linux.
# WD40_PLATFORM overrides detection (test seam, shared with wd40rc/wd40.sh).
detect_platform() {
    echo "${WD40_PLATFORM:-$(uname -s | tr '[:upper:]' '[:lower:]')}"
}

# platform_matches PLATFORM HOST — an empty PLATFORM means every platform.
platform_matches() {
    [ -z "$1" ] || [ "$1" = "$2" ]
}

# Field separator for `read-manifest.py --sep`: unit separator, NOT tab. Tab is
# IFS-whitespace, so `read` collapses empty optional fields and shifts the
# later ones. Use as: `IFS=$MANIFEST_SEP read -r ...`.
MANIFEST_SEP=$'\x1f'

# brew_package_installed INSTALLED_NAMES FORMULA — INSTALLED_NAMES is the
# newline-wrapped output of brew_installed_names. Matches the short name
# (tap/formula -> formula).
brew_package_installed() {
    [[ "$1" == *$'\n'"${2##*/}"$'\n'* ]]
}

# file_sha256 FILE — hex digest; sha256sum on Linux, shasum on macOS.
file_sha256() {
    { sha256sum "$1" 2>/dev/null || shasum -a 256 "$1"; } | cut -d' ' -f1
}
