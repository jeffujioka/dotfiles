#!/bin/bash
# Shared TAP-like output functions for sanity check scripts.
# Sourced by each check-*.sh and by test.sh.

_GREEN='\033[0;32m'
_RED='\033[0;31m'
_YELLOW='\033[0;33m'
_BOLD='\033[1m'
_NC='\033[0m'

# Counters file — shared across sub-scripts via environment variable.
# Each sub-script sources this file and reads/writes the same counters file,
# so the orchestrator (test.sh) sees aggregated totals.
SANITY_COUNTERS_FILE="${SANITY_COUNTERS_FILE:-$(mktemp)}"
export SANITY_COUNTERS_FILE

if [ ! -s "$SANITY_COUNTERS_FILE" ]; then
    printf '0 0 0' > "$SANITY_COUNTERS_FILE"
fi

_update_counter() {
    local field="$1"  # 1=pass, 2=fail, 3=warn
    local counters
    counters=$(cat "$SANITY_COUNTERS_FILE")
    local p f w
    read -r p f w <<< "$counters"
    case "$field" in
        1) p=$((p + 1)) ;;
        2) f=$((f + 1)) ;;
        3) w=$((w + 1)) ;;
    esac
    printf '%d %d %d' "$p" "$f" "$w" > "$SANITY_COUNTERS_FILE"
}

pass() {
    _update_counter 1
    printf "  ${_GREEN}✓${_NC} %s\n" "$1"
}

fail() {
    _update_counter 2
    printf "  ${_RED}✗${_NC} %s\n" "$1"
}

warn() {
    _update_counter 3
    printf "  ${_YELLOW}⚠${_NC} %s\n" "$1"
}

section() {
    printf "\n${_BOLD}=== %s ===${_NC}\n" "$1"
}

summary() {
    local counters
    counters=$(cat "$SANITY_COUNTERS_FILE")
    local p f w
    read -r p f w <<< "$counters"
    printf "\n${_BOLD}════════════════════════${_NC}\n"
    printf "  Results: ${_GREEN}%d passed${_NC}, ${_RED}%d failed${_NC}, ${_YELLOW}%d warnings${_NC}\n" "$p" "$f" "$w"
    printf "${_BOLD}════════════════════════${_NC}\n"
    [ "$f" -eq 0 ]
}

resolve_path() {
    # Portable readlink -f: works on both Linux (GNU) and macOS ARM (BSD).
    # Falls back to Python when GNU coreutils are unavailable.
    readlink -f "$1" 2>/dev/null \
        || python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1"
}
