#!/bin/bash
# Check that brew-installed tools from manifest.toml are available.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

. "$SCRIPT_DIR/helpers.sh"

section "Brew Tools"

if ! command -v brew &>/dev/null; then
    warn "brew not found in PATH — skipping brew tools check"
    exit 0
fi

"$REPO_ROOT/helpers/read-manifest.py" brew.tools --format tsv --fields "formula,binary:" \
    | while IFS=$'\t' read -r formula binary; do
    binary="${binary:-$formula}"
    if command -v "$binary" &>/dev/null; then
        version=$("$binary" --version 2>/dev/null | head -1)
        pass "$formula ($version)"
    else
        fail "$formula not found (binary: $binary)"
    fi
done
