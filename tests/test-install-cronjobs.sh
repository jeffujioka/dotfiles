#!/bin/bash
# Standalone test for install-cronjobs.sh: crontab block (preserve user
# entries, idempotent, placeholder substitution) and launchd plists
# (render, lint, stale removal). Sandboxed $HOME with fake crontab/launchctl.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=helpers.sh
. "$SCRIPT_DIR/helpers.sh"

section "Installer: scheduled jobs (crontab block / launchd plists)"

PASS=0; FAIL=0
t_pass() { PASS=$((PASS+1)); pass "$1"; }
t_fail() { FAIL=$((FAIL+1)); fail "$1"; }
check() { if eval "$2"; then t_pass "$1"; else t_fail "$1"; fi; }

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/home" "$SANDBOX/bin"
export UPD_CHECK_URL=file:///etc/hosts

cat > "$SANDBOX/bin/crontab" <<EOT
#!/bin/bash
f="$SANDBOX/tab"
if [ "\$1" = "-l" ]; then cat "\$f" 2>/dev/null || exit 1; else cat > "\$f"; fi
EOT
cat > "$SANDBOX/bin/launchctl" <<EOT
#!/bin/bash
echo "\$*" >> "$SANDBOX/launchctl.log"
EOT
chmod +x "$SANDBOX/bin/crontab" "$SANDBOX/bin/launchctl"

run() { HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$PATH" WD40_PLATFORM="$1" "$REPO_ROOT/install-cronjobs.sh" >"$SANDBOX/out" 2>&1; }

printf '# mine\n0 1 * * * echo hi\n' > "$SANDBOX/tab"
run linux
check "linux: user entry preserved" "grep -q 'echo hi' '$SANDBOX/tab'"
check "linux: managed block written" "grep -q '^# BEGIN wd40-cronjobs' '$SANDBOX/tab'"
check "linux: schedule is hourly 06-23" "grep -q '^0 6-23 \* \* \* ' '$SANDBOX/tab'"
check "linux: no placeholders left" "! grep -q '@[A-Z0-9]*@' '$SANDBOX/tab'"
before=$(cksum < "$SANDBOX/tab")
run linux
check "linux: second run is a no-op" "[ \"\$(cksum < '$SANDBOX/tab')\" = '$before' ]"

mkdir -p "$SANDBOX/home/Library/LaunchAgents"
printf '<!-- managed by install-cronjobs.sh -->\n' > "$SANDBOX/home/Library/LaunchAgents/com.jfujiok.gone.plist"
printf 'unmanaged\n' > "$SANDBOX/home/Library/LaunchAgents/com.other.plist"
run darwin
plist="$SANDBOX/home/Library/LaunchAgents/com.jfujiok.upd.plist"
check "darwin: plist installed" "[ -f '$plist' ]"
check "darwin: no placeholders left" "! grep -q '@[A-Z0-9]*@' '$plist'"
check "darwin: 18 calendar entries" "[ \"\$(grep -c '<key>Hour</key>' '$plist')\" = 18 ]"
if command -v plutil >/dev/null 2>&1; then
  check "darwin: plist lints" "plutil -lint '$plist' >/dev/null"
fi
check "darwin: stale managed plist removed" "[ ! -e '$SANDBOX/home/Library/LaunchAgents/com.jfujiok.gone.plist' ]"
check "darwin: unmanaged plist kept" "[ -e '$SANDBOX/home/Library/LaunchAgents/com.other.plist' ]"
: > "$SANDBOX/launchctl.log"
run darwin
check "darwin: second run does not reload" "[ ! -s '$SANDBOX/launchctl.log' ]"

mkdir -p "$SANDBOX/home/.local/state/dotfiles/scheduledjobs"
mkdir "$SANDBOX/home/.local/state/dotfiles/scheduledjobs/upd.lock"
HOME="$SANDBOX/home" "$REPO_ROOT/wd40/common/cronjobs/upd.sh"
check "runner: held lock is skipped and logged" "grep -q 'skipped.*lock' '$SANDBOX/home/.local/state/dotfiles/scheduledjobs/upd.log' && ! grep -q 'upd started' '$SANDBOX/home/.local/state/dotfiles/scheduledjobs/upd.log'"

# --- runner: stale lock, failure ---
STATE="$SANDBOX/home/.local/state/dotfiles/scheduledjobs"
mkdir -p "$SANDBOX/stubs"
for t in brew claude npx opencode jq; do
  printf '#!/bin/bash\necho "stub %s $*"\n' "$t" > "$SANDBOX/stubs/$t"; chmod +x "$SANDBOX/stubs/$t"
done
rm -rf "$STATE"; mkdir -p "$STATE/upd.lock"
touch -t 202001010000 "$STATE/upd.lock"
HOME="$SANDBOX/home" PATH="$SANDBOX/stubs:$PATH" "$REPO_ROOT/wd40/common/cronjobs/upd.sh" >/dev/null 2>&1
check "runner: stale lock is broken" "[ -f '$STATE/upd.log' ] && [ ! -e '$STATE/upd.lock' ]"

rm -rf "$STATE"
printf '#!/bin/bash\necho boom\nexit 1\n' > "$SANDBOX/stubs/brew"
HOME="$SANDBOX/home" PATH="$SANDBOX/stubs:$PATH" "$REPO_ROOT/wd40/common/cronjobs/upd.sh" >/dev/null 2>&1
check "runner: upd failure is logged and lock released" "grep -q '(exit 1)' '$STATE/upd.log' && [ ! -e '$STATE/upd.lock' ]"

rm -rf "$STATE"
printf '#!/bin/bash\necho ok\n' > "$SANDBOX/stubs/brew"
UPD_CHECK_URL=http://127.0.0.1:9 HOME="$SANDBOX/home" PATH="$SANDBOX/stubs:$PATH" "$REPO_ROOT/wd40/common/cronjobs/upd.sh" >/dev/null 2>&1
check "runner: offline run is skipped and logged" "grep -q 'skipped.*offline' '$STATE/upd.log' && ! grep -q 'upd started' '$STATE/upd.log' && [ ! -e '$STATE/upd.lock' ]"

rm -rf "$STATE"
printf '#!/bin/bash\necho $$ > "%s/brew.pid"\nsleep 60\n' "$SANDBOX" > "$SANDBOX/stubs/brew"
start=$(date +%s)
UPD_TIMEOUT_SECONDS=2 HOME="$SANDBOX/home" PATH="$SANDBOX/stubs:$PATH" "$REPO_ROOT/wd40/common/cronjobs/upd.sh" >/dev/null 2>&1
elapsed=$(( $(date +%s) - start ))
check "runner: hung upd is killed and logged" "[ $elapsed -lt 30 ] && grep -q 'timed out' '$STATE/upd.log' && [ ! -e '$STATE/upd.lock' ] && ! kill -0 \$(cat '$SANDBOX/brew.pid') 2>/dev/null"

rm -rf "$STATE"
printf '#!/bin/bash\necho "$XDG_CONFIG_HOME" > "%s/brew.xdg"\n' "$SANDBOX" > "$SANDBOX/stubs/brew"
env -u XDG_CONFIG_HOME HOME="$SANDBOX/home" PATH="$SANDBOX/stubs:$PATH" "$REPO_ROOT/wd40/common/cronjobs/upd.sh" >/dev/null 2>&1
check "runner: XDG_CONFIG_HOME defaults to \$HOME/.config (brew trust store)" "[ \"\$(cat '$SANDBOX/brew.xdg')\" = '$SANDBOX/home/.config' ]"

# --- installer edge cases ---
run_fx() { HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$PATH" WD40_PLATFORM="$1" WD40_DIR="$FX" "$REPO_ROOT/install-cronjobs.sh" >"$SANDBOX/out" 2>&1; }
FX="$SANDBOX/fx"; mkdir -p "$FX/common/cronjobs" "$FX/linux/cronjobs" "$FX/darwin/cronjobs"
cp "$REPO_ROOT/wd40/linux/cronjobs/upd.cron" "$FX/linux/cronjobs/"
cp "$REPO_ROOT/wd40/darwin/cronjobs/com.jfujiok.upd.plist" "$FX/darwin/cronjobs/"
rm -f "$SANDBOX/tab"
run_fx linux; rc=$?
check "linux: empty crontab installs block" "[ $rc = 0 ] && grep -q '^# BEGIN wd40-cronjobs' '$SANDBOX/tab'"

rm -f "$SANDBOX/tab"
ODDPATH='/a%b&c:/usr/bin:/bin'
HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$ODDPATH" WD40_PLATFORM=linux WD40_DIR="$FX" /bin/bash "$REPO_ROOT/install-cronjobs.sh" >/dev/null 2>&1
check "linux: % escaped in crontab" "grep -q 'a\\\\%b' '$SANDBOX/tab'"
rm -f "$plist"
HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$ODDPATH" WD40_PLATFORM=darwin WD40_DIR="$FX" /bin/bash "$REPO_ROOT/install-cronjobs.sh" >/dev/null 2>&1
check "darwin: & escaped in plist" "grep -q 'a%b&amp;c' '$plist'"

printf '# mine\n0 1 * * * echo hi\n' > "$SANDBOX/tab"
run_fx linux
rm -f "$FX/linux/cronjobs/upd.cron"
run_fx linux
check "linux: last .cron removed drops block, keeps user lines" "! grep -q wd40-cronjobs '$SANDBOX/tab' && grep -q 'echo hi' '$SANDBOX/tab'"

echo "Scheduled jobs: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
