#!/bin/bash
# Check that symlinks from manifest.toml are correctly set up.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

. "$SCRIPT_DIR/helpers.sh"

section "Symlinks"

expand_path() {
    echo "${1/#\~/$HOME}"
}

"$REPO_ROOT/helpers/read-manifest.py" symlinks --format tsv \
    --fields "source,target,type:symlink" \
    | while IFS=$'\t' read -r src tgt typ; do
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
                # Guard against ln -sf creating a nested symlink inside
                # a directory-targeting symlink (recursive symlink bug).
                if [ -d "$REPO_ROOT/$src" ]; then
                    base=$(basename "$src")
                    if [ -L "$REPO_ROOT/$src/$base" ]; then
                        fail "$src/$base is a recursive symlink (ln -sfn missing?)"
                    fi
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
            failures=0
            for f in $src_pattern; do
                [ -e "$f" ] || continue
                base=$(basename "$f")
                link="$tgt_dir/$base"
                if [ -L "$link" ]; then
                    actual=$(resolve_path "$link")
                    expected=$(resolve_path "$f")
                    if [ "$actual" = "$expected" ]; then
                        matches=$((matches + 1))
                    else
                        fail "$link → $(readlink "$link") (expected $f)"
                        failures=$((failures + 1))
                    fi
                elif [ -e "$link" ]; then
                    fail "$link exists but is not a symlink"
                    failures=$((failures + 1))
                else
                    fail "$link missing"
                    failures=$((failures + 1))
                fi
            done
            if [ "$failures" -eq 0 ] && [ "$matches" -gt 0 ]; then
                pass "$tgt ($matches files linked)"
            elif [ "$matches" -eq 0 ] && [ "$failures" -eq 0 ]; then
                fail "$tgt: no matching source files"
            fi
            ;;
        *)
            warn "Unknown symlink type '$typ' for $tgt"
            ;;
    esac
done
