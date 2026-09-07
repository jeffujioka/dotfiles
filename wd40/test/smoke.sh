#!/usr/bin/env bash
#
# smoke.sh - end-to-end and unit tests for the wd40 tree: wd40.sh, wd40rc,
# and wd40-paths.sh.
#
# Written for bash 3.2 and BSD userland so it runs unchanged on macOS and
# Linux. No test framework on purpose: one file does not justify a
# dependency contributors have to install.
#
# Usage: ./wd40/test/smoke.sh

set -eu

TEST_DIR=$(cd "$(dirname "$0")" && pwd -P)
SOURCE_REPO=$(cd "$(dirname "$0")/../.." && pwd -P)

# One sandbox for the whole run, and one trap to take it away again.
# Everything this file creates lives under it: the copy of the repository
# the tests are aimed at, the file each section's counts come home in, and
# every scratch directory probe_shell makes.
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

# Every command below is run against a copy, never against the working
# tree.
#
# REPO names the copy, and every call site already goes through it. The
# dotfiles repo carries gigabytes of vendored `.git_downloads/`, so the
# copy is partial rather than a whole-repo `cp -a`: only the three things
# the tests need come along.
REPO="$SANDBOX/repo"
mkdir -p "$REPO"
cp -a "$SOURCE_REPO/wd40"          "$REPO/wd40"
cp -a "$SOURCE_REPO/helpers"       "$REPO/helpers"
cp    "$SOURCE_REPO/manifest.toml" "$REPO/manifest.toml"

# Sandbox HOME for the whole run: `wd40 list`'s install marks are read by
# resolving manifest targets like ~/.local/sbin/* and ~/.config/wd40/wd40rc
# against $HOME, so every fixture that exercises those marks must be free
# to plant and remove links there without touching the real developer's
# home directory.
SMOKE_HOME="$SANDBOX/home"
mkdir -p "$SMOKE_HOME"
HOME="$SMOKE_HOME"
export HOME

PASS=0
FAIL=0
SKIP=0

# Where a section's counts come home in.
#
# A section's assertions run in a subshell, so its PASS, FAIL and SKIP are
# the subshell's own and are gone the moment it exits. That is why every
# section total used to be inflated by the two top-level assertions it had
# inherited, why the global total was always `2 passed`, and why one broken
# assertion was reported as nineteen failures. A file is the way back.
COUNTS="$SANDBOX/counts"

pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

# An assertion that was not run, and why.
#
# A run on a machine without zsh drops forty-one assertions, and until this
# existed it printed a summary byte-identical to a full run - so the one
# thing a reader most needed to know was the one thing the output could not
# say.
skip() {
  # skip LABEL REASON
  SKIP=$((SKIP + 1))
  printf '  skip %s (%s)\n' "$1" "$2"
}

# Something worth reading that is not a verdict.
note() { printf '  note %s\n' "$1"; }

# A section runs its assertions in a subshell, and these four helpers are
# what make that subshell reportable.
#
# The subshell used to sit on the left of `||`, which exempts a compound
# command from errexit - and the exemption reaches inside it, so every
# mkdir, cp, ln and `printf >file` that built a fixture was unguarded. A
# section whose setup failed carried on and reported whatever the
# assertions made of the wreckage, and the negative assertions passed
# *harder* for it, because the thing they check for the absence of was
# never created.
#
# Taking the subshell out of that position is only half the fix. Errexit
# has to be off in the parent across the fork, or a section that fails
# kills the run before its status can be read; and it has to be turned back
# on as the subshell's first statement, because the subshell inherits the
# `+e` it was forked under. Neither half works without the other.
section_begin() {
  # section_begin NAME
  printf '\n== %s ==\n' "$1"
  rm -f "$COUNTS"
  set +e
}

section_reset() {
  PASS=0
  FAIL=0
  SKIP=0
}

section_report() {
  printf '%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
  printf '%s %s %s\n' "$PASS" "$FAIL" "$SKIP" > "$COUNTS"
  [ "$FAIL" -eq 0 ] || exit 1
}

# A section that died before section_report leaves no counts behind, and
# that absence is the only evidence there is that its fixtures failed.
# Making a fixture failure visible is the entire point of running the body
# under errexit, so it is counted as one failure of its own rather than
# passing silently for having asserted nothing.
section_end() {
  # section_end RC
  local rc=$1 p f s
  if [ -f "$COUNTS" ]; then
    read -r p f s < "$COUNTS"
    PASS=$((PASS + p))
    FAIL=$((FAIL + f))
    SKIP=$((SKIP + s))
  else
    printf '  FAIL section aborted (rc=%s)\n' "$rc"
    FAIL=$((FAIL + 1))
  fi
  set -e
}

assert_eq() {
  # assert_eq EXPECTED ACTUAL LABEL
  if [ "$1" = "$2" ]; then
    pass "$3"
  else
    fail "$3"
    printf '       expected: %s\n' "$1"
    printf '       actual:   %s\n' "$2"
  fi
}

# Assert that VALUE holds no bytes at all.
#
# `assert_eq "" "$(cmd)"` cannot make that claim: command substitution
# strips every trailing newline, so a command that prints nothing and one
# that prints a bare "\n" arrive here as the same empty string. Counting
# bytes is the only way to tell the two apart, and `capture` below is how a
# caller gets a value with the byte in question still on the end of it.
assert_empty() {
  # assert_empty LABEL VALUE
  local n
  n=$(printf '%s' "$2" | wc -c | tr -d ' ')
  if [ "$n" -eq 0 ]; then
    pass "$1"
  else
    fail "$1 ($n bytes, not none)"
    printf '       actual:   [%s]\n' "$2"
  fi
}

# Run CMD and leave its output in CAPTURED with its trailing newlines on.
#
# The result goes into a variable rather than onto stdout because stdout is
# precisely what would strip it again. Printing a sentinel byte inside the
# substitution and taking it off afterwards is the portable way to keep
# what `$(...)` throws away; bash 3.2 offers nothing better.
capture() {
  # capture CMD...
  CAPTURED=$("$@"; printf X)
  CAPTURED=${CAPTURED%X}
}

# The subshell here is not for isolation. A command killed by a signal
# makes the shell that reaped it print a job-control notice - "Terminated",
# "Segmentation fault" - to its own stderr, which is this log. Running the
# command one level down with that level's stderr closed off puts the
# notice where nobody has to read it, and `exit $?` makes the subshell die
# of its own accord rather than by the same signal, which is what stops
# this shell printing a second copy. The status arrives intact either way.
assert_ok() {
  # assert_ok LABEL CMD...
  local label=$1 rc
  shift
  set +e
  ( "$@" >/dev/null 2>&1; exit $? ) 2>/dev/null
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    pass "$label"
  else
    fail "$label (exit $rc)"
  fi
}

assert_fail() {
  # assert_fail EXPECTED_CODE LABEL CMD...
  local expected=$1 label=$2 actual
  shift 2
  set +e
  ( "$@" >/dev/null 2>&1; exit $? ) 2>/dev/null
  actual=$?
  set -e
  assert_eq "$expected" "$actual" "$label"
}

# Exit 0 *and* nothing on stderr.
#
# assert_ok throws stderr away, so a command that exits 0 while printing
# errors is indistinguishable there from a clean run. That is how this
# suite came to be green over an installer which, pointed at an unwritable
# directory, printed two `link` lines, created nothing, and exited 0.
#
# Nothing calls this yet, on purpose: the installer has to be fixed before
# the assertions that would use it can be green, and a helper adopted
# ahead of its fix only paints the file red without telling anyone
# anything new.
assert_clean() {
  # assert_clean LABEL CMD...
  local label=$1 rc err="$SANDBOX/assert_clean.err"
  shift
  set +e
  ( "$@" >/dev/null 2>"$err"; exit $? ) 2>/dev/null
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    fail "$label (exit $rc)"
  elif [ -s "$err" ]; then
    fail "$label (exit 0, and then wrote to stderr)"
    sed 's/^/       /' "$err"
  else
    pass "$label"
  fi
}

PATHS="$REPO/wd40/common/shell/wd40-paths.sh"

# wd40/common/shell/wd40-paths.sh claims to behave identically under bash 3.2 and zsh,
# and that is the easiest claim in the design to break without noticing:
# nothing in a bash-only test run would ever fail. So every assertion about
# it runs once per shell in this list.
#
# zsh is not installed everywhere, and a missing zsh is not a defect in
# wd40, so it is skipped with a note rather than failed.
SHELLS="bash"
if command -v zsh >/dev/null 2>&1; then
  SHELLS="bash zsh"
fi

# Run SNIPPET under SHELL and describe the result as one comparable line.
#
# The line carries a line count for each stream as well as its first line.
# Both are needed: "stdout was empty" and "stdout's first line was empty"
# are different claims, and a test that cannot tell them apart would pass
# on a function that printed a stray blank line. Collapsing a whole run
# into one string also keeps a fourteen-row table to fourteen assertions
# instead of seventy.
#
# CLEAN-PATH, when given, is the whole environment: the shell is started
# under `env -i` with that PATH and nothing else. Assigning `WD40_CLIP=`
# inside the snippet only makes the variable empty, which is one of the
# two things `_wd40_clip` treats as absent - close enough for the
# cascade, and not close enough for a claim about a machine that has
# nothing. The interpreter is resolved before `env -i` takes the PATH
# away, because otherwise `env` would look for it on the new one.
probe_shell() {
  # probe_shell SHELL SNIPPET [CLEAN-PATH]
  local sh=$1 snippet=$2 clean=${3:-} dir rc outn errn out1 err1
  # Under the run sandbox, so that the trap on it collects the two hundred
  # of these a run makes. On its own each is removed below; on an interrupt
  # none of them were.
  dir=$(mktemp -d "$SANDBOX/probe.XXXXXX")
  set +e
  if [ -n "$clean" ]; then
    ( env -i PATH="$clean" "$(command -v "$sh")" -c "$snippet" \
        >"$dir/out" 2>"$dir/err"; exit $? ) 2>/dev/null
  else
    ( "$sh" -c "$snippet" >"$dir/out" 2>"$dir/err"; exit $? ) 2>/dev/null
  fi
  rc=$?
  set -e
  outn=$(wc -l < "$dir/out" | tr -d ' ')
  errn=$(wc -l < "$dir/err" | tr -d ' ')
  out1=$(head -n 1 "$dir/out")
  err1=$(head -n 1 "$dir/err")
  rm -rf "$dir"
  printf 'rc=%s out=%s err=%s out1=[%s] err1=[%s]\n' \
    "$rc" "$outn" "$errn" "$out1" "$err1"
}

section_begin 'run sandbox'
(
  set -e
  section_reset

  # Everything below this point is aimed at the copy, so a `cp -a` that
  # quietly dropped a file, a mode or a symlink would leave the whole run
  # testing something other than the repository - and saying so afterwards
  # is no use, because by then the assertions have already agreed with the
  # wrong tree. Only wd40/, helpers/ and manifest.toml are copied (the
  # dotfiles repo carries gigabytes of vendored .git_downloads/ that the
  # tests do not need), so the comparison is scoped to those three rather
  # than the whole of SOURCE_REPO.
  #
  # Content and modes are asked about separately because `diff -r` follows
  # symlinks and says nothing whatever about permissions, which is the one
  # thing the copy exists to protect.
  assert_empty "the wd40/ copy is the repository's, byte for byte" \
    "$(diff -r "$SOURCE_REPO/wd40" "$REPO/wd40" 2>&1 || true)"
  assert_empty "the helpers/ copy is the repository's, byte for byte" \
    "$(diff -r "$SOURCE_REPO/helpers" "$REPO/helpers" 2>&1 || true)"
  assert_empty "manifest.toml is the repository's, byte for byte" \
    "$(diff "$SOURCE_REPO/manifest.toml" "$REPO/manifest.toml" 2>&1 || true)"

  # `stat -c` is GNU and `stat -f` is BSD; the first ten characters of an
  # `ls -ld` line are neither, and they carry the file's type as well as
  # its mode, so a symlink that arrived as a regular file shows up here too.
  modes_of() {
    # modes_of DIR
    ( cd "$1" && find . -print | LC_ALL=C sort | while IFS= read -r p; do
        printf '%s %s\n' "$(ls -ld "$p" | cut -c1-10)" "$p"
      done )
  }
  assert_eq "$(modes_of "$SOURCE_REPO/wd40")" "$(modes_of "$REPO/wd40")" \
    "and wd40/ carries every mode the repository had"
  assert_eq "$(modes_of "$SOURCE_REPO/helpers")" "$(modes_of "$REPO/helpers")" \
    "and helpers/ carries every mode the repository had"

  # The one assertion that has to hold for any of the others to be safe to
  # run at all: every fixture below writes under $SMOKE_HOME, never the
  # developer's own.
  assert_eq "$SANDBOX/home" "$HOME" "HOME is the sandbox and not the developer's"

  section_report
)
section_end $?

section_begin 'bash 3.2 and BSD portability'
(
  set -e
  section_reset

  # Every file scanned below claims bash 3.2 in its header, and the claim
  # is the one thing this suite cannot test by running anything: it
  # resolves `bash` through PATH, which here is bash 5 and on macOS is
  # usually a Homebrew build, so the half of the matrix that exists to
  # defend the claim never runs on the version in question. Installing bash
  # 3.2 to fix that is not on offer, so the claim is guarded statically
  # instead - and the version that did run is reported rather than assumed.
  note "bash is $(command -v bash) ($(bash --version | sed -n '1p'))"
  if [ "$SHELLS" = "bash" ]; then
    note "zsh is not on PATH; the assertions that need one are skipped below"
  else
    note "zsh is $(command -v zsh) ($(zsh --version))"
  fi

  # Reading the raw text would fail on the documentation of the very rule
  # being enforced: every construct on the list below is named in these
  # files' headers, in prose, precisely because it is forbidden. So the
  # text is scanned first and the constructs are looked for in what is
  # left.
  #
  # This is a scanner and not a shell parser. It follows single quotes,
  # double quotes, backslash escapes, here-documents, and the `#` that
  # opens a comment only at the start of a word, and it starts each line
  # afresh - so a string spanning several lines is read as code. That is
  # deliberate: the failure it produces is a false positive, which is loud
  # and gets fixed, rather than a false negative, which is silent and is
  # the failure this whole section exists to prevent.
  #
  # The program itself lives in a quoted here-document because a quoted
  # here-document is data, and the scanner skips it. A scanner that read
  # its own source as shell would be the first thing to trip it.
  STRIPPER=$(cat <<'AWK'
  heredoc != "" {
    line = $0
    sub(/^[[:space:]]+/, "", line)
    if (line == heredoc) heredoc = ""
    print ""
    next
  }
  {
    out = ""
    q = ""
    n = length($0)
    for (i = 1; i <= n; i++) {
      c = substr($0, i, 1)
      if (q == "s") { if (c == "\047") q = ""; continue }
      if (q == "d") {
        if (c == "\\") { i++; continue }
        if (c == "\"") q = ""
        continue
      }
      if (c == "\\")   { i++; out = out " "; continue }
      if (c == "\047") { q = "s"; out = out " "; continue }
      if (c == "\"")   { q = "d"; out = out " "; continue }
      if (c == "#" && (out == "" || substr(out, length(out), 1) ~ /[[:space:];&|(]/)) break
      out = out c
    }
    print out
    if (index(out, "<<") > 0 && match($0, /<<-?[[:space:]]*[\047"]?[A-Za-z_][A-Za-z0-9_]*[\047"]?/)) {
      w = substr($0, RSTART, RLENGTH)
      sub(/^<<-?[[:space:]]*/, "", w)
      gsub(/[\047"]/, "", w)
      heredoc = w
    }
  }
AWK
)

  # One pass per file rather than one per file and construct, with the name
  # and line number carried along so a hit can be gone straight to.
  #
  # The list is every wd40-native bash file this repository ships that
  # claims bash 3.2. DEFAULT-IN policy: a new wd40-native bash file gets
  # added to GUARDED_FILES below; absorbed scripts (from the old dotfiles
  # bin/) are EXEMPT - they target modern macOS/Linux and use
  # readlink -f / set -euo pipefail by design. whatsapp-diskusage.py is
  # Python and out of the guard's domain.
  GUARDED_FILES="
wd40/common/scripts/wd40.sh
wd40/common/scripts/smem-groups.sh
wd40/common/shell/wd40-paths.sh
wd40/wd40rc
wd40/test/smoke.sh
"
  code="$SANDBOX/portability-code"
  : > "$code"
  for f in $GUARDED_FILES; do
    awk "$STRIPPER" "$REPO/$f" |
      awk -v name="$f" '{ printf "%s:%d: %s\n", name, NR, $0 }' >> "$code"
  done

  # `--` before the pattern, and it is the difference between a guard and a
  # decoration. `find -printf`'s pattern begins with `-p`, grep read it as a
  # flag bundle, and answered `invalid option -- 'p'` with status 2; `|| true`
  # then swallowed the status, `hits` came back empty, and the row passed
  # unconditionally. A real `find . -printf '%p\n'`, planted in the guard's
  # own probe file below, is reported as `ok no find -printf` without it.
  # Every future pattern opening with `-`
  # inherited the same fault, which is why the fix is `--` here rather than a
  # rewritten pattern there.
  #
  # The two probes below carry `--` for the same reason even though their
  # patterns are literals that begin with a letter: the rule is about where
  # the pattern comes from, not about what today's happens to say.
  forbids() {
    # forbids LABEL PATTERN
    local hits
    hits=$(grep -E -- "$2" "$code" || true)
    if [ -z "$hits" ]; then
      pass "no $1"
    else
      fail "no $1"
      printf '%s\n' "$hits" | sed 's/^/       /'
    fi
  }

  # The list the two headers forbid, as patterns rather than as prose. The
  # flag forms are written to catch the flag wherever it sits in a bundle,
  # so `grep -rn` is caught by the same row as `grep -r`.
  #
  # The fields are split on '@' rather than the '|' used by the table in
  # == fp contract ==, because almost every pattern here is an
  # alternation and one of them is `|&` itself.
  while IFS='@' read -r label pattern; do
    [ -n "$label" ] || continue
    forbids "$label" "$pattern"
  done <<'CONSTRUCTS'
associative arrays@(declare|typeset|local)[[:space:]]+-[A-Za-z]*A
${var,,}@\$\{[A-Za-z_][A-Za-z0-9_]*(,,|\^\^)
mapfile@(^|[^A-Za-z0-9_.-])mapfile([^A-Za-z0-9_-]|$)
readarray@(^|[^A-Za-z0-9_.-])readarray([^A-Za-z0-9_-]|$)
globstar@globstar
readlink -f@readlink[[:space:]]+-[A-Za-z]*f
realpath@(^|[^A-Za-z0-9_.-])realpath([^A-Za-z0-9_-]|$)
timeout@(^|[^A-Za-z0-9_.-])timeout([^A-Za-z0-9_-]|$)
seq@(^|[^A-Za-z0-9_.-])seq([^A-Za-z0-9_-]|$)
grep -P@grep[[:space:]]+-[A-Za-z]*P
grep -r@grep[[:space:]]+-[A-Za-z]*[rR]
sed -i@sed[[:space:]]+-[A-Za-z]*i
sed -r@sed[[:space:]]+-[A-Za-z]*r
find -printf@-printf([^A-Za-z0-9_-]|$)
stat -c@stat[[:space:]]+-[A-Za-z]*c
echo -e@echo[[:space:]]+-[A-Za-z]*e
echo -n@echo[[:space:]]+-[A-Za-z]*n
&>@&>
|&@\|&
coproc@(^|[^A-Za-z0-9_.-])coproc([^A-Za-z0-9_-]|$)
wait -n@wait[[:space:]]+-[A-Za-z]*n
shopt@(^|[^A-Za-z0-9_.-])shopt([^A-Za-z0-9_-]|$)
CONSTRUCTS

  # A guard that cannot fire is worse than no guard at all, and the twenty-
  # two assertions above stay green whether the scanner works or returns
  # nothing at all. These two are the difference between the two states.
  probe="$SANDBOX/portability-probe.sh"
  {
    printf '# a comment that names realpath\n'
    printf 'x="realpath in a double-quoted string"\n'
    printf "y='realpath in a single-quoted one'\n"
  } > "$probe"
  assert_empty "prose and quoted text are read as neither" \
    "$(awk "$STRIPPER" "$probe" | grep -E -- 'realpath' || true)"

  printf 'realpath /tmp\n' >> "$probe"
  assert_eq "realpath /tmp" \
    "$(awk "$STRIPPER" "$probe" | grep -E -- 'realpath' | sed 's/^ *//;s/ *$//')" \
    "and a real use of one is read as code"

  # And the pattern that could not be looked for until `--` was added. A row
  # of the table above is only worth its line if planting the construct it
  # names turns it red, and this is the one row where planting it did not.
  printf 'find . -printf "%%p\\n"\n' >> "$probe"
  assert_eq "find . -printf" \
    "$(awk "$STRIPPER" "$probe" | grep -E -- '-printf([^A-Za-z0-9_-]|$)' | sed 's/^ *//;s/ *$//')" \
    "and a pattern beginning with a dash reaches grep as a pattern"

  section_report
)
section_end $?

section_begin 'fp contract'
(
  set -e
  section_reset
  # Said from in here, like every other skip: a note printed between the
  # header and the subshell is a note the section's own counts never saw.
  if [ "$SHELLS" = "bash" ]; then
    skip "the whole zsh half of this section" "zsh is not on PATH"
  fi
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  scratch=$(cd "$tmp" && pwd -P)

  # Every row of the contract table in the design, asserted verbatim.
  #
  # The columns are ARGSPEC|RC|OUT_LINES|OUT_FIRST|ERR_LINES|ERR_FIRST, and
  # the fields are split on '|' alone so that a value may contain spaces.
  # Do not pad this table with alignment spaces: they would be data.
  #
  # ARGSPEC is encoded rather than quoted because several of the rows are
  # about argument *shape* - "no argument at all", "one empty-string
  # argument", "two arguments", "options after `--`" - and none of those
  # survives being written as an ordinary field. @S@ stands in for the
  # scratch directory, which is not known until now.
  #
  # Every call carries `--no-clipboard`. This section is about the path,
  # and a machine with a working clipboard is not a thing a test may
  # assume it is running on; the section below this one is where the
  # clipboard is the subject.
  run_gp_table() {
    # run_gp_table SHELL
    local sh=$1 argspec rc outn out1 errn err1 call expected
    while IFS='|' read -r argspec rc outn out1 errn err1; do
      [ -n "$argspec" ] || continue
      case $argspec in
        @NONE@)   call='fp --no-clipboard' ;;
        @EMPTY@)  call="fp --no-clipboard ''" ;;
        @TWO@)    call='fp --no-clipboard a b' ;;
        @ENDOPT@) call='fp --no-clipboard -- --relative' ;;
        @SWAP@)   call='fp --relative --no-clipboard' ;;
        *)        call="fp --no-clipboard '$argspec'" ;;
      esac
      expected="rc=$rc out=$outn err=$errn out1=[${out1//@S@/$scratch}] err1=[$err1]"
      assert_eq "$expected" \
        "$(probe_shell "$sh" "cd '$scratch' || exit 9; . '$PATHS'; $call")" \
        "$sh: fp $argspec"
    done <<'TABLE'
@NONE@|0|1|@S@|0|
foo/bar|0|1|@S@/foo/bar|0|
./foo/bar|0|1|@S@/foo/bar|0|
.|0|1|@S@|0|
./|0|1|@S@|0|
../foo|0|1|@S@/../foo|0|
foo/|0|1|@S@/foo/|0|
/foo/bar|0|1|/foo/bar|0|
/|0|1|/|0|
-anything-else|0|1|@S@/-anything-else|0|
@ENDOPT@|0|1|@S@/--relative|0|
@SWAP@|0|1|.|0|
-h|0|15|usage: fp [OPTIONS] [--] [PATH]|0|
--help|0|15|usage: fp [OPTIONS] [--] [PATH]|0|
@EMPTY@|2|0||15|usage: fp [OPTIONS] [--] [PATH]
@TWO@|2|0||16|fp: too many arguments (expected at most one path)
TABLE
  }

  # --relative takes the current directory off the front and does nothing
  # else, so this is the table above read through that one rule.
  #
  # It is driven through `fpn` rather than through `fp --no-clipboard`,
  # which makes every row an assertion about a shorthand as well: one that
  # dropped "$@" would answer for the current directory, and only the rows
  # that pass an argument would notice.
  #
  # The last two rows are the ones the rule exists for. A target outside
  # the current directory keeps its absolute spelling instead of growing a
  # `../../` walk, and @S@X is the sibling trap: it begins with every
  # character of the scratch directory and is a different directory, which
  # only a pattern insisting on the separator can tell apart.
  run_gpr_table() {
    # run_gpr_table SHELL
    local sh=$1 argspec rc outn out1 errn err1 call expected
    while IFS='|' read -r argspec rc outn out1 errn err1; do
      [ -n "$argspec" ] || continue
      case $argspec in
        @NONE@) call='fpn --relative' ;;
        *)      call="fpn --relative '${argspec//@S@/$scratch}'" ;;
      esac
      expected="rc=$rc out=$outn err=$errn out1=[${out1//@S@/$scratch}] err1=[$err1]"
      assert_eq "$expected" \
        "$(probe_shell "$sh" "cd '$scratch' || exit 9; . '$PATHS'; $call")" \
        "$sh: fpn --relative $argspec"
    done <<'TABLE'
@NONE@|0|1|.|0|
foo/bar|0|1|foo/bar|0|
./foo/bar|0|1|foo/bar|0|
.|0|1|.|0|
./|0|1|.|0|
../foo|0|1|../foo|0|
foo/|0|1|foo/|0|
@S@/a/b|0|1|a/b|0|
@S@|0|1|.|0|
/|0|1|/|0|
/nowhere-near-the-scratch/x|0|1|/nowhere-near-the-scratch/x|0|
@S@X/x|0|1|@S@X/x|0|
TABLE
  }

  for sh in $SHELLS; do
    run_gp_table "$sh"
    run_gpr_table "$sh"

    # This file is sourced into a live interactive shell, so a `set -e` or
    # `set -o pipefail` escaping from it would make a typo at the prompt
    # fatal. Comparing the whole option table catches pipefail, which $-
    # does not report.
    assert_eq "rc=0 out=0 err=0 out1=[] err1=[]" \
      "$(probe_shell "$sh" "b=\$(set -o); . '$PATHS'; a=\$(set -o); [ \"\$b\" = \"\$a\" ]")" \
      "$sh: sourcing changes no shell option"

    # WHY THE SHORTHANDS ARE FUNCTIONS AND NOT ALIASES
    #
    # bash expands an alias only when `expand_aliases` is on, and it is off
    # in every non-interactive shell - which is every shell this suite
    # starts. An alias would be `command not found` here and would work at
    # a prompt, which is precisely the difference between the two shells
    # that this file promises it does not have. This assertion is what
    # turns that promise red if somebody rewrites the three as aliases.
    assert_eq "rc=0 out=1 err=0 out1=[$scratch/foo] err1=[]" \
      "$(probe_shell "$sh" "cd '$scratch' || exit 9; . '$PATHS'; fpn foo")" \
      "$sh: fpn reaches fp with its argument intact"

    # A shorthand prepends a flag, so a user who repeats that same flag by
    # hand sends it twice without ever seeing it twice. The parse sets a
    # variable rather than counting, which is what makes the repetition
    # mean nothing - and what stops an error message naming a word the
    # user did not write.
    assert_eq "rc=0 out=1 err=0 out1=[foo] err1=[]" \
      "$(probe_shell "$sh" "cd '$scratch' || exit 9; . '$PATHS'; fpnr --no-clipboard foo")" \
      "$sh: a flag a shorthand already supplied is not an error"

    # One command means one name in every message, whichever shorthand
    # routed there. That is the opposite of the rule this file used to
    # carry - two commands sharing an implementation had to be told apart -
    # and it is right for the same reason: the name in the message is the
    # name of the thing the user can read the help of, and `fpr --help`
    # prints fp's.
    assert_eq "rc=2 out=0 err=16 out1=[] err1=[fp: too many arguments (expected at most one path)]" \
      "$(probe_shell "$sh" "cd '$scratch' || exit 9; . '$PATHS'; fpr a b")" \
      "$sh: a shorthand's argument error names fp"
  done

  section_report
)
section_end $?

section_begin 'fp and the clipboard'
(
  set -e
  section_reset
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  scratch=$(cd "$tmp" && pwd -P)

  # A clipboard that can be read back afterwards. $WD40_CLIP holds a
  # command name and is invoked quoted, so a path to a script is exactly
  # what it wants; `command -v` accepts one.
  cap="$scratch/clipboard"
  clip_ok="$scratch/clip-ok"
  clip_fails="$scratch/clip-fails"
  printf '#!/bin/sh\ncat > "%s"\n' "$cap" > "$clip_ok"
  printf '#!/bin/sh\ncat > /dev/null\nexit 3\n'  > "$clip_fails"
  chmod +x "$clip_ok" "$clip_fails"

  # A cascade command that exists and then does not work. This is the
  # author's own failure mode - ~/.local/bin/pbcopy forwards over SSH and
  # there is nothing listening - and it is reached by name rather than
  # through WD40_CLIP, so it needs a directory of its own on PATH. The
  # real directories stay on PATH behind it: the stub still needs `cat`,
  # and a shim shadowing the rest of PATH is exactly the arrangement being
  # imitated.
  fakebin="$scratch/fakebin"
  mkdir -p "$fakebin"
  printf '#!/bin/sh\ncat > /dev/null\nexit 3\n' > "$fakebin/pbcopy"
  chmod +x "$fakebin/pbcopy"

  # And a PATH with none of the five on it, which is the one branch of the
  # cascade nothing had ever reached: the machine with no clipboard at all.
  # An empty directory is the whole of it - _wd40_clip runs no external
  # command on the way to giving up, and `fp` needs none either, so
  # there is nothing for the shell to fail to find.
  emptybin="$scratch/emptybin"
  mkdir -p "$emptybin"

  run_gp() {
    # run_gp SHELL ASSIGNMENT ARGS
    probe_shell "$1" "cd '$scratch' || exit 9; . '$PATHS'; $2 fp $3"
  }

  if [ "$SHELLS" = "bash" ]; then
    skip "the whole zsh half of this section" "zsh is not on PATH"
  fi
  for sh in $SHELLS; do
    # THE STREAM CONTRACT
    #
    # The path goes to stdout whether it was copied or not, and stderr
    # stays empty on the way through. The arrangement this replaces put
    # the path on stdout when it was printed and on stderr when it was
    # copied, which was defensible while those were two commands and is a
    # trap now that a flag chooses between them: `fp foo > file` and
    # `fpn foo > file` would have captured different things, and the
    # difference would have left no mark on the output.
    rm -f "$cap"
    assert_eq "rc=0 out=1 err=0 out1=[$scratch/foo] err1=[]" \
      "$(run_gp "$sh" "WD40_CLIP='$clip_ok'" foo)" \
      "$sh: the path goes to stdout and stderr stays empty"

    # A path with a newline on the end, pasted at a prompt, runs
    # immediately. Byte counts, because a trailing newline is exactly what
    # a string comparison would throw away.
    assert_eq "$scratch/foo" "$(cat "$cap")" "$sh: the clipboard got the path"
    assert_eq "$(printf '%s' "$scratch/foo" | wc -c | tr -d ' ')" \
      "$(wc -c < "$cap" | tr -d ' ')" \
      "$sh: the clipboard got it with no trailing newline"

    # --no-clipboard is the whole of the difference: same stdout, and a
    # clipboard that was never opened.
    rm -f "$cap"
    assert_eq "rc=0 out=1 err=0 out1=[$scratch/foo] err1=[]" \
      "$(run_gp "$sh" "WD40_CLIP='$clip_ok'" "--no-clipboard foo")" \
      "$sh: --no-clipboard prints the same path"
    assert_fail 1 "$sh: and leaves the clipboard alone" test -e "$cap"

    # --help is answered before anything is copied, or the usage text
    # itself would be what landed on the clipboard.
    rm -f "$cap"
    assert_eq "rc=0 out=15 err=0 out1=[usage: fp [OPTIONS] [--] [PATH]] err1=[]" \
      "$(run_gp "$sh" "WD40_CLIP='$clip_ok'" --help)" \
      "$sh: fp --help describes fp on stdout"
    assert_fail 1 "$sh: fp --help did not touch the clipboard" test -e "$cap"

    # A CLIPBOARD THAT FAILS DOES NOT COST THE CALLER THE PATH
    #
    # out=1 in all four of the failing rows below, and it is the half of
    # each assertion that is new. The path is printed first and the
    # clipboard is attempted after, so a machine with no clipboard on it
    # still answers the question that was asked - and still says, on
    # stderr and in the exit status, that the copy did not happen.
    #
    # The user said what they wanted; a WD40_CLIP that is not a command is
    # an error, not a reason to fall through to the cascade.
    rm -f "$cap"
    assert_eq "rc=1 out=1 err=1 out1=[$scratch/foo] err1=[wd40: WD40_CLIP names \"definitely-not-a-real-command\", which is not a command]" \
      "$(run_gp "$sh" "WD40_CLIP=definitely-not-a-real-command" foo)" \
      "$sh: an unfindable WD40_CLIP exits 1 and names it"
    assert_fail 1 "$sh: and copies nothing" test -e "$cap"

    # A clipboard command that runs and then fails used to be the one
    # failure nobody was told about: no receipt, no error, exit 1, and the
    # user left to work out that the missing receipt *was* the error.
    #
    # err=1 is the rest of the assertion. One line on stderr, naming the
    # command and its exit status. That the status survives at all proves
    # the pipeline's exit code is read correctly, which this file has to
    # manage without `set -o pipefail`.
    rm -f "$cap"
    assert_eq "rc=1 out=1 err=1 out1=[$scratch/foo] err1=[wd40: $clip_fails failed (exit 3); nothing was copied]" \
      "$(run_gp "$sh" "WD40_CLIP='$clip_fails'" foo)" \
      "$sh: a WD40_CLIP that fails names itself and its exit status"

    # The same for a command the cascade chose rather than one the user
    # named. Every branch that runs a command reports the same way, and
    # this is the branch a real machine actually reaches.
    rm -f "$cap"
    assert_eq "rc=1 out=1 err=1 out1=[$scratch/foo] err1=[wd40: pbcopy failed (exit 3); nothing was copied]" \
      "$(run_gp "$sh" "WD40_CLIP= PATH='$fakebin:/usr/bin:/bin'" foo)" \
      "$sh: a cascade command that fails names itself and its exit status"

    # An argument error is the one case with nothing on stdout: there is
    # no path to print, because none could be worked out. It copies
    # nothing on the way out either.
    rm -f "$cap"
    assert_eq "rc=2 out=0 err=16 out1=[] err1=[fp: too many arguments (expected at most one path)]" \
      "$(run_gp "$sh" "WD40_CLIP='$clip_ok'" "a b")" \
      "$sh: two arguments exit 2"
    assert_fail 1 "$sh: and copy nothing" test -e "$cap"

    rm -f "$cap"
    assert_eq "rc=2 out=0 err=15 out1=[] err1=[usage: fp [OPTIONS] [--] [PATH]]" \
      "$(run_gp "$sh" "WD40_CLIP='$clip_ok'" "''")" \
      "$sh: an empty argument exits 2"
    assert_fail 1 "$sh: and copies nothing either" test -e "$cap"

    # NO CLIPBOARD COMMAND AT ALL
    #
    # The bottom of the cascade: a machine with none of pbcopy, wl-copy,
    # xclip or xsel on it. Two lines on stderr, because the second is the
    # way out - naming WD40_CLIP is what turns "this does not work here"
    # into something the user can act on. And still out=1: on such a
    # machine `fp` is `fpn` with a diagnostic, which is a usable command
    # rather than a broken one.
    rm -f "$cap"
    assert_eq "rc=1 out=1 err=2 out1=[$scratch/foo] err1=[wd40: no clipboard command found (tried pbcopy, wl-copy, xclip, xsel)]" \
      "$(run_gp "$sh" "WD40_CLIP= PATH='$emptybin'" foo)" \
      "$sh: no clipboard command anywhere exits 1 and says which it looked for"
    assert_fail 1 "$sh: and copies nothing" test -e "$cap"

    # The second line is the half a first-line assertion cannot see.
    set +e
    "$sh" -c "cd '$scratch' || exit 9; . '$PATHS'; WD40_CLIP= PATH='$emptybin' fp foo" \
      >/dev/null 2>"$scratch/noclip.err"
    set -e
    assert_eq 'wd40: set WD40_CLIP to the name of a command that reads stdin' \
      "$(sed -n '2p' "$scratch/noclip.err")" \
      "$sh: and the second line says how to fix it"
  done

  section_report
)
section_end $?

section_begin 'wd40'
(
  set -e
  section_reset

  # This section's assertions are against a single command's whole
  # result - stdout, stderr and exit code together - which the harness's
  # own capture (stdout only, via a sentinel byte) and assert_ok/assert_fail
  # (which run a command themselves rather than check one already run) do
  # not provide together. Shadowing all three here is safe: each section is
  # its own subshell fork (see section_begin's comment above), so the
  # redefinitions vanish with it and every other section keeps the
  # originals.
  capture() {
    # capture CMD... - sets CAP_OUT, CAP_ERR, CAP_RC (all three, unlike
    # the top-level capture, which is stdout-only and does not need RC).
    local _errf _rcf
    _errf=$(mktemp "$SANDBOX/cap-err.XXXXXX")
    _rcf=$(mktemp "$SANDBOX/cap-rc.XXXXXX")
    set +e
    CAP_OUT=$("$@" 2>"$_errf"; printf '%d' "$?" > "$_rcf"; printf X)
    set -e
    CAP_OUT=${CAP_OUT%X}
    CAP_RC=$(cat "$_rcf")
    CAP_ERR=$(cat "$_errf"; printf X)
    CAP_ERR=${CAP_ERR%X}
    rm -f "$_errf" "$_rcf"
  }
  assert_ok() {
    # assert_ok LABEL - asserts the last capture's CAP_RC is 0
    if [ "$CAP_RC" -eq 0 ]; then pass "$1"; else fail "$1 (exit $CAP_RC)"; fi
  }
  assert_fail() {
    # assert_fail LABEL - asserts the last capture's CAP_RC is nonzero
    if [ "$CAP_RC" -ne 0 ]; then pass "$1"; else fail "$1 (exit 0)"; fi
  }

  WD40="$REPO/wd40/common/scripts/wd40.sh"

  # bare wd40: usage on stdout, exit 0 — a question, not a mistake
  capture bash "$WD40"
  assert_ok        "bare wd40 exits 0"
  assert_eq "$(printf '%s' "$CAP_OUT" | head -1)" "Usage: wd40 <command>" \
                   "bare wd40 prints usage on stdout"
  assert_empty "bare wd40 says nothing on stderr" "$CAP_ERR"

  # help spellings
  for h in help -h --help; do
    capture bash "$WD40" "$h"
    assert_ok "wd40 $h exits 0"
  done

  # unknown argument: usage on stderr, exit 1
  capture bash "$WD40" frobnicate
  assert_fail      "unknown argument exits 1"
  assert_empty "unknown argument prints nothing on stdout" "$CAP_OUT"

  # an argument to an argumentless command
  capture bash "$WD40" list --json
  assert_fail      "wd40 list --json exits 1"

  # root anchoring: a WD40_ROOT with no manifest.toml is refused
  NOROOT=$(mktemp -d)
  capture env WD40_ROOT="$NOROOT" bash "$WD40" list
  assert_fail      "a root without manifest.toml is refused"
  rm -rf "$NOROOT"

  section_report
)
section_end $?

section_begin 'wd40 list'
(
  set -e
  section_reset

  # Same local capture/assert_ok/assert_fail as the 'wd40' section above
  # (see its comment) - redefined here because each section is its own
  # subshell fork and this one needs the same semantics.
  capture() {
    # capture CMD... - sets CAP_OUT, CAP_ERR, CAP_RC
    local _errf _rcf
    _errf=$(mktemp "$SANDBOX/cap-err.XXXXXX")
    _rcf=$(mktemp "$SANDBOX/cap-rc.XXXXXX")
    set +e
    CAP_OUT=$("$@" 2>"$_errf"; printf '%d' "$?" > "$_rcf"; printf X)
    set -e
    CAP_OUT=${CAP_OUT%X}
    CAP_RC=$(cat "$_rcf")
    CAP_ERR=$(cat "$_errf"; printf X)
    CAP_ERR=${CAP_ERR%X}
    rm -f "$_errf" "$_rcf"
  }
  assert_ok() {
    # assert_ok LABEL - asserts the last capture's CAP_RC is 0
    if [ "$CAP_RC" -eq 0 ]; then pass "$1"; else fail "$1 (exit $CAP_RC)"; fi
  }
  assert_fail() {
    # assert_fail LABEL - asserts the last capture's CAP_RC is nonzero
    if [ "$CAP_RC" -ne 0 ]; then pass "$1"; else fail "$1 (exit 0)"; fi
  }

  WD40="$REPO/wd40/common/scripts/wd40.sh"

  # --- fixture: minimal root with manifest, scripts, shell, local ---
  FIX="$SANDBOX/listfix"
  mkdir -p "$FIX/wd40/common/scripts" "$FIX/wd40/common/shell" \
           "$FIX/wd40/linux/scripts" "$FIX/wd40/local/shell" "$FIX/helpers"
  cp "$REPO/helpers/read-manifest.py" "$FIX/helpers/"
  cat > "$FIX/manifest.toml" <<'EOF'
[[symlinks]]
source = "wd40/wd40rc"
target = "~/.config/wd40/wd40rc"

[[symlinks]]
source = "wd40/common/scripts/*"
target = "~/.local/sbin/*"
type = "glob"
strip_ext = true

[[symlinks]]
source = "wd40/linux/scripts/*"
target = "~/.local/sbin/*"
type = "glob"
strip_ext = true
platform = "linux"
EOF
  printf '#!/bin/sh\n# wd40: alpha - the alpha script\n:\n' > "$FIX/wd40/common/scripts/alpha.sh"
  printf '#!/bin/sh\n# wd40: tuxonly - linux-only script\n:\n' > "$FIX/wd40/linux/scripts/tuxonly.sh"
  printf '# wd40: fn-one - a shell function\n' > "$FIX/wd40/common/shell/fns.sh"
  printf '#!/usr/bin/env bash\n:\n' > "$FIX/wd40/wd40rc"

  # --- discovery + platform filter (darwin sees no tuxonly) ---
  capture env WD40_ROOT="$FIX" WD40_PLATFORM=darwin bash "$WD40" list
  assert_ok "list over the fixture exits 0"
  case $CAP_OUT in *alpha*) pass "lists alpha" ;; *) fail "alpha missing from list" ;; esac
  case $CAP_OUT in *tuxonly*) fail "linux-only script listed on darwin" ;; *) pass "platform filter applied" ;; esac
  case $CAP_OUT in *fn-one*) pass "lists shell declaration" ;; *) fail "shell declaration missing" ;; esac

  # linux platform sees tuxonly
  capture env WD40_ROOT="$FIX" WD40_PLATFORM=linux bash "$WD40" list
  case $CAP_OUT in *tuxonly*) pass "linux platform lists tuxonly" ;; *) fail "tuxonly missing on linux" ;; esac

  # --- marks: uninstalled = !, installed (link resolving into root) = clear ---
  capture env WD40_ROOT="$FIX" WD40_PLATFORM=darwin HOME="$SMOKE_HOME" bash "$WD40" list
  case $CAP_OUT in *'! '*alpha*) pass "uninstalled alpha marked !" ;; *) fail "missing ! mark" ;; esac

  mkdir -p "$SMOKE_HOME/.local/sbin" "$SMOKE_HOME/.config/wd40"
  ln -sfn "$FIX/wd40/common/scripts/alpha.sh" "$SMOKE_HOME/.local/sbin/alpha"
  ln -sfn "$FIX/wd40/wd40rc"                  "$SMOKE_HOME/.config/wd40/wd40rc"
  capture env WD40_ROOT="$FIX" WD40_PLATFORM=darwin HOME="$SMOKE_HOME" bash "$WD40" list
  case $CAP_OUT in *'! '*alpha*) fail "installed alpha still marked !" ;; *) pass "installed alpha unmarked" ;; esac
  rm -f "$SMOKE_HOME/.local/sbin/alpha" "$SMOKE_HOME/.config/wd40/wd40rc"

  # --- local/ leniency: undeclared local file warns, exit stays 0 ---
  printf 'alias mystery=1\n' > "$FIX/wd40/local/shell/mystery.sh"
  capture env WD40_ROOT="$FIX" WD40_PLATFORM=darwin bash "$WD40" list
  assert_ok "undeclared local file does not fail the run"
  case $CAP_ERR in *mystery.sh*) pass "local file warned about on stderr" ;; *) fail "no warning for local file" ;; esac

  # --- strict refusal: undeclared tracked shell file ---
  printf 'alias nope=1\n' > "$FIX/wd40/common/shell/undeclared.sh"
  capture env WD40_ROOT="$FIX" WD40_PLATFORM=darwin bash "$WD40" list
  assert_fail "undeclared tracked file is refused"
  rm -f "$FIX/wd40/common/shell/undeclared.sh"

  # --- strict refusal: declared name ≠ strip-rule install name ---
  printf '#!/bin/sh\n# wd40: wrongname - mismatch\n:\n' > "$FIX/wd40/common/scripts/actual.sh"
  capture env WD40_ROOT="$FIX" WD40_PLATFORM=darwin bash "$WD40" list
  assert_fail "declared-name mismatch is refused"
  rm -f "$FIX/wd40/common/scripts/actual.sh"

  # --- the REAL repo copy also lists cleanly ---
  capture env WD40_ROOT="$REPO" WD40_PLATFORM=darwin HOME="$SMOKE_HOME" bash "$WD40" list
  assert_ok "wd40 list over the real tree exits 0"

  section_report
)
section_end $?

section_begin 'loader wiring'
(
  set -e
  section_reset

  LOADFIX="$SANDBOX/loadfix"
  mkdir -p "$LOADFIX/common/shell" "$LOADFIX/darwin/shell" "$LOADFIX/linux/shell"
  cp "$REPO/wd40/wd40rc" "$LOADFIX/wd40rc"
  printf 'alias t_common=1\n'     > "$LOADFIX/common/shell/a.sh"
  printf 'return 1\n'             > "$LOADFIX/common/shell/b-fails.sh"
  printf 'alias t_after=1\n'      > "$LOADFIX/common/shell/c.sh"
  printf 'alias t_darwin=1\n'     > "$LOADFIX/darwin/shell/d.sh"
  printf 'alias t_linux=1\n'      > "$LOADFIX/linux/shell/l.sh"
  ln -s /nonexistent "$LOADFIX/common/shell/dangling.sh"

  for sh in $SHELLS; do
    out=$("$sh" -c "WD40_PLATFORM=darwin . '$LOADFIX/wd40rc' 2>'$SANDBOX/lderr'
      alias t_common >/dev/null 2>&1 && printf C
      alias t_after  >/dev/null 2>&1 && printf A
      alias t_darwin >/dev/null 2>&1 && printf D
      alias t_linux  >/dev/null 2>&1 && printf L
      set | grep -c '^_wd40_' || true" )
    assert_eq "$out" "CAD0" "$sh: sources common+platform, survives a failing file, skips other platform, cleans vars"
    grep -q 'skipped unreadable' "$SANDBOX/lderr" \
      && pass "$sh: dangling symlink warned about" \
      || fail "$sh: no dangling-symlink warning"
  done

  # empty dirs must not error (zsh nullglob path)
  for sh in $SHELLS; do
    EMPTYFIX="$SANDBOX/emptyfix"; mkdir -p "$EMPTYFIX/common/shell"
    cp "$REPO/wd40/wd40rc" "$EMPTYFIX/wd40rc"
    if "$sh" -c ". '$EMPTYFIX/wd40rc'" 2>"$SANDBOX/emerr"; then
      assert_empty "$sh: empty shell dirs stay silent" "$(cat "$SANDBOX/emerr")"
    else
      fail "$sh: loader errors on empty dirs"
    fi
    rm -rf "$EMPTYFIX"
  done

  section_report
)
section_end $?

section_begin 'absorbed shell files under both shells'
(
  set -e
  section_reset

  # common/shell must SOURCE cleanly under bash 3.2 (/bin/bash on macOS) and
  # zsh — bash gets these files for the first time after cutover. Platform
  # dirs only need to PARSE everywhere (their commands don't exist cross-OS).
  for sh in $SHELLS; do
    for f in "$REPO"/wd40/common/shell/*.sh; do
      if "$sh" -c ". '$f'" >/dev/null 2>"$SANDBOX/srcerr"; then
        pass "$sh sources $(basename "$f")"
      else
        note "$(cat "$SANDBOX/srcerr")"
        fail "$sh fails sourcing $(basename "$f")"
      fi
    done
    for f in "$REPO"/wd40/linux/shell/*.sh "$REPO"/wd40/darwin/shell/*.sh; do
      [ -e "$f" ] || continue
      if "$sh" -n "$f" 2>"$SANDBOX/synerr"; then
        pass "$sh -n $(basename "$f")"
      else
        note "$(cat "$SANDBOX/synerr")"
        fail "$sh -n fails on $(basename "$f")"
      fi
    done
  done

  section_report
)
section_end $?

section_begin 'scripts are executable and carry shebangs'
(
  set -e
  section_reset

  for f in "$REPO"/wd40/common/scripts/* "$REPO"/wd40/darwin/scripts/* "$REPO"/wd40/linux/scripts/*; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    [ -x "$f" ] && pass "$b is executable" || fail "$b is not executable"
    case $(head -1 "$f") in
      '#!'*) pass "$b has a shebang" ;;
      *)     fail "$b has no shebang" ;;
    esac
  done

  section_report
)
section_end $?

section_begin 'co-location invariant'
(
  set -e
  section_reset

  # starship-picker and tmux-palette call each other via $SCRIPT_DIR and MUST
  # stay in one directory (spec §Target Layout).
  if [ -f "$REPO/wd40/common/scripts/starship-picker" ] \
     && [ -f "$REPO/wd40/common/scripts/tmux-palette" ]; then
    pass "starship-picker and tmux-palette are co-located"
  else
    fail "starship-picker and tmux-palette are NOT in the same directory"
  fi

  section_report
)
section_end $?

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
