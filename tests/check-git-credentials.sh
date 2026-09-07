#!/bin/bash
# Fail if any git configuration file contains a credential in cleartext.
#
# Credentials belong in a credential helper (gh, glab, the OS keyring), never
# in a config file. This check exists because a personal access token lived
# for months inside a URL rewrite, where nothing looked at it.
#
# Deliberately host-agnostic: it matches credential SHAPES, not specific
# hostnames, because this repository is public.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

. "$SCRIPT_DIR/helpers.sh"

section "Git credential hygiene"

# Forge token prefixes, plus the generic "userinfo carries a password" form
# https://user:secret@host — which is how a previous credential was stored.
TOKEN_PATTERNS='glpat-[A-Za-z0-9_.-]+|gh[pousr]_[A-Za-z0-9]+|github_pat_[A-Za-z0-9_]+|://[^/[:space:]]+:[^/@[:space:]]+@'

CONFIG_FILES=(
    "$HOME/.gitconfig"
    "$HOME/.config/git/config"
)
# Identity files, if the directory exists at all.
if [ -d "$HOME/.config/git/configs" ]; then
    for f in "$HOME/.config/git/configs"/*; do
        [ -f "$f" ] && CONFIG_FILES+=("$f")
    done
fi

found=0
for f in "${CONFIG_FILES[@]}"; do
    [ -f "$f" ] || continue
    # Report line numbers only. Never echo a matched value.
    hits=$(grep -nEc "$TOKEN_PATTERNS" "$f" 2>/dev/null || true)
    hits=${hits:-0}
    if [ "$hits" -gt 0 ]; then
        lines=$(grep -nE "$TOKEN_PATTERNS" "$f" | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
        fail "${f/#$HOME/\~} — credential pattern on line(s): $lines"
        found=$((found + 1))
    else
        pass "${f/#$HOME/\~} — no credential patterns"
    fi
done

# Permissions: identity files are secrets even once detokenized, since they
# carry certificate paths and routing for internal infrastructure.
if [ -d "$HOME/.config/git/configs" ]; then
    dir_mode=$(stat -f '%Lp' "$HOME/.config/git/configs" 2>/dev/null) \
               || dir_mode=$(stat -c '%a' "$HOME/.config/git/configs")
    if [ "$dir_mode" = "700" ]; then
        pass "~/.config/git/configs is 0700"
    else
        fail "~/.config/git/configs is $dir_mode (expected 700)"
        found=$((found + 1))
    fi

    for f in "$HOME/.config/git/configs"/*; do
        [ -f "$f" ] || continue
        mode=$(stat -f '%Lp' "$f" 2>/dev/null) || mode=$(stat -c '%a' "$f")
        if [ "$mode" = "600" ]; then
            pass "${f/#$HOME/\~} is 0600"
        else
            fail "${f/#$HOME/\~} is $mode (expected 600)"
            found=$((found + 1))
        fi
    done
else
    warn "~/.config/git/configs does not exist (G1 not migrated yet?)"
fi

[ "$found" -eq 0 ]
