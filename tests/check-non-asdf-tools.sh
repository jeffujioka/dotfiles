#!/bin/bash
# Check that non-asdf resources from manifest.toml are present.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

. "$SCRIPT_DIR/helpers.sh"

section "Non-asdf Tools"

expand_path() {
    local p="$1"
    # Expand ~ to $HOME, resolve relative paths against repo root
    p="${p/#\~/$HOME}"
    if [[ "$p" != /* ]]; then
        p="$REPO_ROOT/$p"
    fi
    echo "$p"
}

host_platform="${WD40_PLATFORM:-$(uname -s | tr '[:upper:]' '[:lower:]')}"

# Unit-separator delimiter: tab would collapse empty optional fields.
"$REPO_ROOT/helpers/read-manifest.py" resources --format tsv --sep $'\x1f' \
    --fields "name,type,path,creates,platform" \
    | while IFS=$'\x1f' read -r name rtype rpath creates platform; do
    rpath=$(expand_path "$rpath")

    case "$rtype" in
        git-clone)
            if [ -d "$rpath/.git" ]; then
                pass "$name ($rpath)"
            else
                fail "$name not found at $rpath"
            fi
            ;;
        file-download)
            if [ -f "$rpath" ]; then
                pass "$name ($rpath)"
            else
                fail "$name not found at $rpath"
            fi
            ;;
        script-install)
            if [ -n "$platform" ] && [ "$platform" != "$host_platform" ]; then
                continue
            fi
            if command -v "$creates" &>/dev/null; then
                pass "$name ($creates)"
            else
                fail "$name not found (binary: $creates)"
            fi
            ;;
        *)
            warn "$name: unknown resource type '$rtype'"
            ;;
    esac
done
