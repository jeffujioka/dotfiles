#!/bin/bash
# Check that symlinks from manifest.toml are correctly set up.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

. "$SCRIPT_DIR/helpers.sh"

section "Symlinks"

expand_path() {
    echo "${1/#\~/$HOME}"
}

"$REPO_ROOT/helpers/read-manifest.py" symlinks --format jsonl | while IFS= read -r line; do
    src=$(printf '%s' "$line" | python3 -c "import sys,json; print(json.load(sys.stdin)['source'])")
    tgt=$(printf '%s' "$line" | python3 -c "import sys,json; print(json.load(sys.stdin)['target'])")
    typ=$(printf '%s' "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('type','symlink'))")
    tgt=$(expand_path "$tgt")

    case "$typ" in
        symlink)
            if [ -L "$tgt" ]; then
                actual=$(resolve_path "$tgt")
                expected=$(resolve_path "$REPO_ROOT/$src")
                if [ "$actual" = "$expected" ]; then
                    pass "$tgt → $src"
                else
                    fail "$tgt → $(basename "$actual") (expected $src)"
                fi
            elif [ -e "$tgt" ]; then
                fail "$tgt exists but is not a symlink"
            else
                fail "$tgt missing"
            fi
            ;;
        copy)
            if [ -f "$tgt" ]; then
                pass "$tgt exists (copy)"
            else
                fail "$tgt not found (expected copy of $src)"
            fi
            ;;
        glob)
            src_pattern="$REPO_ROOT/$src"
            tgt_dir=$(dirname "$tgt")
            matches=0
            for f in $src_pattern; do
                [ -e "$f" ] || continue
                base=$(basename "$f")
                if [ -e "$tgt_dir/$base" ] || [ -L "$tgt_dir/$base" ]; then
                    matches=$((matches + 1))
                fi
            done
            if [ "$matches" -gt 0 ]; then
                pass "$tgt ($matches files linked)"
            else
                fail "$tgt: no matching files found"
            fi
            ;;
        *)
            warn "Unknown symlink type '$typ' for $tgt"
            ;;
    esac
done
