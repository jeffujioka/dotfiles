#!/usr/bin/env bash
# wd40: occ - run opencode attached to the OpenChamber-managed shared server
#
# Plain `opencode` stays untouched (its own background service). `occ` points
# the CLI at the server OpenChamber started so both see the same sessions.
#
# The server's port is discovered at runtime: it is the `opencode serve`
# process whose ancestry includes OpenChamber (macOS desktop app, Linux web
# service). Password: $OPENCODE_SERVER_PASSWORD, else OPENCODE_SERVER_PASSWORD
# (then OPENCHAMBER_UI_PASSWORD) from ~/.config/openchamber/startup.env, else the
# macOS Keychain.
# Override with OPENCODE_SHARED_SERVER_URL / OPENCODE_SHARED_SERVER_KEYCHAIN.

# Prints "<pid> <host> <port>" for OpenChamber's opencode server, or nothing.
_occ_discover() {
  local line pid host port
  line="$(ps -axo pid=,ppid=,args= 2>/dev/null | awk '
    { pid = $1; par[pid] = $2; $1 = $2 = ""; args[pid] = $0 }
    END {
      for (p in args) {
        if (args[p] !~ /^ *[^ ]*opencode serve / || args[p] ~ /--service/) continue
        a = p; found = 0
        for (i = 0; i < 6 && (a in par); i++) {
          a = par[a]
          if (tolower(args[a]) ~ /openchamber/) { found = 1; break }
        }
        if (!found) continue
        host = "127.0.0.1"; port = ""
        n = split(args[p], w, " ")
        for (j = 1; j <= n; j++) {
          if (w[j] == "--port") port = w[j + 1]
          else if (w[j] == "--hostname") host = w[j + 1]
        }
        print p, host, port
        exit
      }
    }')"
  [ -n "$line" ] || return 1
  read -r pid host port <<EOF2
$line
EOF2
  if [ -z "$port" ] && command -v lsof >/dev/null 2>&1; then
    port="$(lsof -a -p "$pid" -iTCP -sTCP:LISTEN -Fn 2>/dev/null | sed -n 's/^n.*:\([0-9][0-9]*\)$/\1/p' | head -1)"
  fi
  [ -n "$port" ] || return 1
  echo "$pid $host $port"
}

opencode_chamber() {
  # keep `set -x` from tracing the password; restored when the function returns
  [ -n "${ZSH_VERSION:-}" ] && setopt localoptions noxtrace
  local url="${OPENCODE_SHARED_SERVER_URL:-}" found pid host port pw=""

  if [ -z "$url" ]; then
    if ! found="$(_occ_discover)"; then
      echo "occ: OpenChamber's opencode server not found; start OpenChamber or use plain opencode" >&2
      return 1
    fi
    read -r pid host port <<EOF2
$found
EOF2
    url="http://$host:$port"
  fi

  if [ -z "${OPENCODE_SERVER_PASSWORD:-}" ]; then
    local envfile="${OPENCHAMBER_STARTUP_ENV:-$HOME/.config/openchamber/startup.env}" key
    if [ -r "$envfile" ]; then
      for key in OPENCODE_SERVER_PASSWORD OPENCHAMBER_UI_PASSWORD; do
        pw="$(sed -n "s/^$key=//p" "$envfile" | head -1 | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/")"
        [ -n "$pw" ] && break
      done
    fi
    if [ -z "$pw" ] && command -v security >/dev/null 2>&1; then
      pw="$(security find-generic-password -s "${OPENCODE_SHARED_SERVER_KEYCHAIN:-openchamber-opencode}" -w 2>/dev/null)"
    fi
    [ -n "${pw:-}" ] && local -x OPENCODE_SERVER_PASSWORD="$pw"
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
