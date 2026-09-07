#!/bin/bash
# Run the wd40 smoke suite and fold its verdict into the sanity-check
# counters. The suite has its own PASS/FAIL machinery and summary line;
# here it collapses to one pass/fail so the aggregate summary stays honest.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

. "$SCRIPT_DIR/helpers.sh"

section "wd40 smoke suite"

out=$("$REPO_ROOT/wd40/test/smoke.sh" 2>&1)
rc=$?
verdict=$(printf '%s\n' "$out" | tail -1)

if [ "$rc" -eq 0 ]; then
    pass "wd40/test/smoke.sh — $verdict"
else
    # Full dump, not a tail: a red run must be self-diagnosing from this
    # sanity-check's own console, and the smoke suite's own output is
    # already concise enough that truncating it only hides the failure.
    printf '%s\n' "$out"
    fail "wd40/test/smoke.sh — $verdict"
fi

exit "$rc"
