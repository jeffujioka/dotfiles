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

host_platform=$(detect_platform)

"$REPO_ROOT/helpers/read-manifest.py" resources --format tsv --sep "$MANIFEST_SEP" \
    --fields "name,type,path,creates,platform" \
    | while IFS=$MANIFEST_SEP read -r name rtype rpath creates platform; do
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
            platform_matches "$platform" "$host_platform" || continue
            if command -v "$creates" &>/dev/null; then
                pass "$name ($creates)"
            else
                fail "$name not found (creates: $creates)"
            fi
            ;;
        *)
            warn "$name: unknown resource type '$rtype'"
            ;;
    esac
done
