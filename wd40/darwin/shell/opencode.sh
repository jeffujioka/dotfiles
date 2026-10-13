#!/usr/bin/env bash
# wd40: occ - run opencode attached to the OpenChamber-managed shared server
#
# Plain `opencode` stays untouched (its own background service). `occ` points
# the CLI at the server OpenChamber started so both see the same sessions.
# Override with OPENCODE_SHARED_SERVER_URL / OPENCODE_SHARED_SERVER_KEYCHAIN.

opencode_chamber() {
  # keep `set -x` from tracing the password; restored when the function returns
  [ -n "${ZSH_VERSION:-}" ] && setopt localoptions noxtrace
  local url="${OPENCODE_SHARED_SERVER_URL:-http://127.0.0.1:5555}"
  local hostport="${url#*://}"
  hostport="${hostport%%/*}"

  if ! nc -z "${hostport%:*}" "${hostport##*:}" >/dev/null 2>&1; then
    echo "occ: OpenChamber not running (nothing on $url); start it or use plain opencode" >&2
    return 1
  fi

  if [ -z "${OPENCODE_SERVER_PASSWORD:-}" ]; then
    local pw
    pw="$(security find-generic-password -s "${OPENCODE_SHARED_SERVER_KEYCHAIN:-openchamber-opencode}" -w 2>/dev/null)"
    [ -n "$pw" ] && local -x OPENCODE_SERVER_PASSWORD="$pw"
  fi

  case "${1:-}" in
    run|api)
      local sub="$1"; shift
      command opencode "$sub" --server "$url" "$@"
      ;;
    *)
      command opencode --server "$url" "$@"
      ;;
  esac
}

alias occ=opencode_chamber
