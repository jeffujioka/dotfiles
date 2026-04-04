#!/bin/bash
# Check that non-asdf resources from manifest.toml are present.

set -e

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

"$REPO_ROOT/helpers/read-manifest.py" resources --format jsonl | while IFS= read -r line; do
    name=$(printf '%s' "$line" | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])")
    rtype=$(printf '%s' "$line" | python3 -c "import sys,json; print(json.load(sys.stdin)['type'])")
    rpath=$(printf '%s' "$line" | python3 -c "import sys,json; print(json.load(sys.stdin)['path'])")
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
        *)
            warn "$name: unknown resource type '$rtype'"
            ;;
    esac
done
