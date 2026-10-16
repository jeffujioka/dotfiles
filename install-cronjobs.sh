#!/usr/bin/env bash
# Installs the scheduled jobs under wd40/{common,<platform>}/cronjobs/.
#   linux:  every *.cron fragment goes into one managed crontab block
#   darwin: every *.plist goes to ~/Library/LaunchAgents and is reloaded;
#           managed plists no longer in the repo are removed
# Placeholders: @PATH@ (PATH of the invoking shell), @HOME@, @WD40@.
# Re-run after changing a job or your PATH.
set -o pipefail

script_dir=$(dirname "$(readlink -f "$0")")
wd40_dir="${WD40_DIR:-$script_dir/wd40}"
platform="${WD40_PLATFORM:-$(uname -s | tr '[:upper:]' '[:lower:]')}"
begin_marker="# BEGIN wd40-cronjobs"
end_marker="# END wd40-cronjobs"
plist_marker="managed by install-cronjobs.sh"

# render FILE MODE(cron|1): cron escapes %, 1 XML-escapes: print FILE with placeholders replaced.
render() {
  R_PATH="$PATH" R_HOME="$HOME" R_WD40="$wd40_dir" R_ESC="$2" awk '
    function lit(s, pat, rep,   out, i) {
      out = ""
      while ((i = index(s, pat)) > 0) {
        out = out substr(s, 1, i - 1) rep
        s = substr(s, i + length(pat))
      }
      return out s
    }
    function esc(v) {
      if (ENVIRON["R_ESC"] == "cron") return lit(v, "%", "\\%")
      if (ENVIRON["R_ESC"] != "1") return v
      v = lit(v, "&", "&amp;"); v = lit(v, "<", "&lt;"); return lit(v, ">", "&gt;")
    }
    { $0 = lit($0, "@PATH@", esc(ENVIRON["R_PATH"]))
      $0 = lit($0, "@HOME@", esc(ENVIRON["R_HOME"]))
      print lit($0, "@WD40@", esc(ENVIRON["R_WD40"])) }
  ' "$1"
}

job_files() {
  local ext="$1" dir f
  for dir in common "$platform"; do
    for f in "$wd40_dir/$dir/cronjobs/"*."$ext"; do
      [ -f "$f" ] && echo "$f"
    done
  done
}

warn_missing_tools() {
  local tool
  for tool in brew npx claude; do
    command -v "$tool" >/dev/null 2>&1 \
      || echo "Warning: '$tool' is not on PATH; scheduled jobs will not find it." >&2
  done
}

install_linux() {
  command -v crontab >/dev/null 2>&1 || { echo "Error: crontab not found." >&2; return 1; }
  local current block f
  current=$(crontab -l 2>/dev/null || true)
  block=""
  while IFS= read -r f; do
    block="${block}$(render "$f" cron)"$'\n'
  done < <(job_files cron)

  local kept
  kept=$(printf '%s\n' "$current" | awk -v b="$begin_marker" -v e="$end_marker" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }')
  kept=$(printf '%s' "$kept" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')

  local new="$kept"
  if [ -n "$block" ]; then
    new="${new:+$new$'\n\n'}$begin_marker"$'\n'"$block$end_marker"
  fi
  if [ "$new" = "$(printf '%s' "$current" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')" ]; then
    echo "crontab already up to date."
    return 0
  fi
  printf '%s\n' "$new" | crontab - || return 1
  echo "crontab updated."
}

install_darwin() {
  local agents_dir="$HOME/Library/LaunchAgents" uid f name dest tmp
  uid=$(id -u)
  mkdir -p "$agents_dir"
  local wanted=" "
  while IFS= read -r f; do
    name=$(basename "$f")
    wanted="$wanted$name "
    dest="$agents_dir/$name"
    tmp=$(mktemp) || return 1
    render "$f" 1 >"$tmp"
    if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
      rm -f "$tmp"
      echo "$name already up to date."
      continue
    fi
    mv "$tmp" "$dest"
    launchctl bootout "gui/$uid" "$dest" 2>/dev/null || true
    launchctl bootstrap "gui/$uid" "$dest" && echo "$name loaded."
  done < <(job_files plist)

  for dest in "$agents_dir"/*.plist; do
    [ -f "$dest" ] || continue
    grep -q "$plist_marker" "$dest" || continue
    name=$(basename "$dest")
    case "$wanted" in *" $name "*) continue ;; esac
    launchctl bootout "gui/$uid" "$dest" 2>/dev/null || true
    rm -f "$dest" && echo "$name removed (no longer in repo)."
  done
}

warn_missing_tools
case "$platform" in
  linux) install_linux ;;
  darwin) install_darwin ;;
  *) echo "Unsupported platform: $platform" >&2; exit 1 ;;
esac
