#!/usr/bin/env bash
# Scheduled job: run `upd` (wd40/common/shell/update.sh) without a terminal.
# Skips (and logs) if a previous run is still going or the network is down;
# kills a run that exceeds the timeout; keeps the last 1000 log lines.

here=$(cd "$(dirname "$0")" && pwd)
state_dir="$HOME/.local/state/dotfiles/scheduledjobs"
lock="$state_dir/upd.lock"
log="$state_dir/upd.log"
max_log_lines=1000
stale_lock_minutes=120
timeout_seconds="${UPD_TIMEOUT_SECONDS:-2700}"
check_url="${UPD_CHECK_URL:-https://github.com}"

# launchd/cron do not set this; without it Homebrew reads ~/.homebrew/trust.json
# instead of ~/.config/homebrew/trust.json and ignores trusted-tap formulae.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

mkdir -p "$state_dir" || exit 1

stamp() { date '+%F %T'; }

trim_log() {
  [ -f "$log" ] || return 0
  tail -n "$max_log_lines" "$log" >"$log.tmp" && mv "$log.tmp" "$log"
}

if ! mkdir "$lock" 2>/dev/null; then
  if [ -n "$(find "$lock" -maxdepth 0 -mmin +"$stale_lock_minutes" 2>/dev/null)" ]; then
    rmdir "$lock" 2>/dev/null && mkdir "$lock" 2>/dev/null || exit 0
  else
    echo "=== upd skipped $(stamp) (previous run still holds the lock) ===" >>"$log"
    exit 0
  fi
fi
trap 'rmdir "$lock" 2>/dev/null' EXIT

trim_log

if command -v curl >/dev/null 2>&1 && ! curl -sS -o /dev/null --max-time 10 "$check_url" 2>/dev/null; then
  echo "=== upd skipped $(stamp) (offline: cannot reach $check_url) ===" >>"$log"
  trim_log
  exit 0
fi

echo "=== upd started $(stamp) ===" >>"$log"

# Own process group (set -m) so the timeout can kill brew/npx children too.
set -m
bash -c '. "$1"; upd' _ "$here/../shell/update.sh" </dev/null >>"$log" 2>&1 &
pid=$!
( sleep "$timeout_seconds"; kill -TERM -- "-$pid" 2>/dev/null; sleep 5; kill -KILL -- "-$pid" 2>/dev/null ) &
watchdog=$!
wait "$pid"
rc=$?
pkill -P "$watchdog" 2>/dev/null
kill "$watchdog" 2>/dev/null
wait "$watchdog" 2>/dev/null

if [ "$rc" -eq 143 ] || [ "$rc" -eq 137 ]; then
  echo "=== upd timed out after ${timeout_seconds}s and was killed $(stamp) ===" >>"$log"
else
  echo "=== upd finished $(stamp) (exit $rc) ===" >>"$log"
fi
trim_log
