#!/bin/bash
# Check that asdf tools from .tool-versions are installed with expected versions.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

. "$SCRIPT_DIR/helpers.sh"

section "asdf Tools"

if ! command -v asdf &>/dev/null; then
    fail "asdf not found"
    exit 0
fi

asdf_ver=$(asdf version 2>/dev/null | sed 's/^v//')
pass "asdf $asdf_ver"

get_binary() {
    case "$1" in
        rust) echo "rustc" ;;
        *)    echo "$1" ;;
    esac
}

get_version() {
    local tool="$1"
    case "$tool" in
        rust) rustc --version 2>/dev/null | awk '{print $2}' ;;
        tmux) tmux -V 2>/dev/null | awk '{print $2}' ;;
        glab) glab --version 2>/dev/null | awk '{print $3}' ;;
        *)    "$tool" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+[0-9.]*' | head -1 ;;
    esac
}

while IFS= read -r line; do
    # Skip comments and blank lines
    case "$line" in \#*|"") continue ;; esac

    tool=$(echo "$line" | awk '{print $1}')
    expected=$(echo "$line" | awk '{print $2}')
    binary=$(get_binary "$tool")

    if command -v "$binary" &>/dev/null; then
        installed=$(get_version "$tool")
        if [ "$installed" = "$expected" ]; then
            pass "$tool $installed"
        else
            warn "$tool $installed (expected $expected)"
        fi
    else
        fail "$tool not found (binary: $binary)"
    fi
done < "$REPO_ROOT/.tool-versions"
