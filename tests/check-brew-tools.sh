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

installed_names=$'\n'"$(brew_installed_names)"$'\n'
host_platform="${WD40_PLATFORM:-$(uname -s | tr '[:upper:]' '[:lower:]')}"

"$REPO_ROOT/helpers/read-manifest.py" brew.tools --format tsv --fields "formula,binary:,platform:" \
    | while IFS=$'\t' read -r formula binary platform; do
    if [ -n "$platform" ] && [ "$platform" != "$host_platform" ]; then
        continue
    fi
    binary="${binary:-$formula}"
    if command -v "$binary" &>/dev/null; then
        # `|| true`: some tools exit nonzero on --version; under
        # `set -eo pipefail` that would silently kill the whole check.
        version=$("$binary" --version 2>/dev/null | head -1 || true)
        pass "$formula ($version)"
    elif [[ "$installed_names" == *$'\n'"${formula##*/}"$'\n'* ]]; then
        pass "$formula (installed via brew, no binary on PATH)"
    else
        fail "$formula not found (binary: $binary)"
    fi
done
