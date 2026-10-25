#!/bin/bash
# Run the Hammerspoon unit tests for config/hammerspoon inside the live
# Hammerspoon, through the hs CLI. Darwin-only; skipped elsewhere.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

. "$SCRIPT_DIR/helpers.sh"

section "Hammerspoon"

HOST_PLATFORM="${WD40_PLATFORM:-$(uname -s | tr '[:upper:]' '[:lower:]')}"
if [ "$HOST_PLATFORM" != "darwin" ]; then
    warn "Hammerspoon tests are darwin-only, skipped"
    exit 0
fi

HS="$(command -v hs || true)"
if [ -z "$HS" ] || ! "$HS" -A -q -t 5 -c '1' >/dev/null 2>&1; then
    warn "Hammerspoon CLI unavailable, skipped"
    exit 0
fi

out=$("$HS" -A -q -t 5 "$REPO_ROOT/tests/hammerspoon/secure_input_watch_test.lua" "$REPO_ROOT" 2>&1)
if [ "$out" = "ok" ]; then
    pass "secure_input_watch decision logic"
else
    fail "secure_input_watch decision logic: $out"
    exit 1
fi
