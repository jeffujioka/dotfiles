#!/bin/bash
# Check that system packages from manifest.toml are installed.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

. "$SCRIPT_DIR/helpers.sh"

section "System Packages"

if [[ "$OSTYPE" == darwin* ]]; then
    manifest_key="packages.darwin.list"
    check_installed() { brew list "$1" &>/dev/null; }
elif [[ "$OSTYPE" == linux* ]]; then
    manifest_key="packages.linux.list"
    check_installed() { dpkg -s "$1" &>/dev/null; }
else
    fail "Unsupported OS: $OSTYPE"
    exit 1
fi

"$REPO_ROOT/helpers/read-manifest.py" "$manifest_key" | while IFS= read -r pkg; do
    if check_installed "$pkg"; then
        pass "$pkg installed"
    else
        fail "$pkg not found"
    fi
done
