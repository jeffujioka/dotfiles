#!/bin/bash
# Check that cargo-installed tools from manifest.toml are available.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

. "$SCRIPT_DIR/helpers.sh"

section "Cargo Tools"

if ! command -v cargo &>/dev/null; then
    fail "cargo not found in PATH"
    exit 0
fi

"$REPO_ROOT/helpers/read-manifest.py" cargo.tools | while IFS= read -r tool; do
    if command -v "$tool" &>/dev/null; then
        version=$("$tool" --version 2>/dev/null | head -1)
        pass "$tool ($version)"
    else
        fail "$tool not found"
    fi
done
