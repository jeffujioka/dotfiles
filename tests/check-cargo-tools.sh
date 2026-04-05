#!/bin/bash
# Check that cargo-installed tools from manifest.toml are available.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

. "$SCRIPT_DIR/helpers.sh"

section "Cargo Tools"

if ! command -v cargo &>/dev/null; then
    fail "cargo not found in PATH"
    exit 0
fi

"$REPO_ROOT/helpers/read-manifest.py" cargo.tools --format tsv --fields "crate,binary:" \
    | while IFS=$'\t' read -r crate binary; do
    binary="${binary:-$crate}"
    if command -v "$binary" &>/dev/null; then
        version=$("$binary" --version 2>/dev/null | head -1)
        pass "$crate ($version)"
    else
        fail "$crate not found (binary: $binary)"
    fi
done
