#!/usr/bin/env bash
#
# wd40.sh - what this repository provides, and whether it is installed.
#
# wd40: wd40 - list the commands this repository provides
#
# Discovery is manifest-driven: manifest.toml owns which globs install
# scripts, where they land, and where the wd40rc loader link lives.
# helpers/read-manifest.py reports those facts, so this file never
# hardcodes what the installer owns — one source of truth, no drift.
#
# `local/` is machine-local, gitignored content: its shell files are
# listed leniently (warnings, never a nonzero exit) and local/scripts is
# not discovered at all (no manifest entry installs it).
#
# Targets bash 3.2 and BSD userland; guarded by wd40/test/smoke.sh.
#
# Usage: wd40 help

set -eu

# --- locate the repository --------------------------------------------------
# Invoked through ~/.local/sbin/wd40, `dirname "$0"` names the install dir,
# not the repo: walk the symlink chain by hand. 40 hops is the kernel's own
# ELOOP cap, and it stops a symlink cycle from hanging a discovery command.
wd40_self=$0
wd40_hops=0
while [ -L "$wd40_self" ] && [ "$wd40_hops" -lt 40 ]; do
  wd40_link=$(readlink "$wd40_self")
  case $wd40_link in
    /*) wd40_self=$wd40_link ;;
    *)  wd40_self=$(dirname "$wd40_self")/$wd40_link ;;
  esac
  wd40_hops=$((wd40_hops + 1))
done
if [ -L "$wd40_self" ]; then
  printf 'Error: cannot find this repository: %s is a symlink cycle\n' "$0" >&2
  exit 1
fi

# Root = three levels above the resolved file's directory:
#   <root>/wd40/common/scripts/wd40.sh
# WD40_ROOT overrides discovery (the test seam for sandboxed fixtures), and
# either way the answer is anchored: no manifest.toml, no repository.
if [ -n "${WD40_ROOT:-}" ]; then
  WD40_REPO=$(cd "$WD40_ROOT" && pwd -P) || {
    printf 'Error: WD40_ROOT does not exist: %s\n' "$WD40_ROOT" >&2
    exit 1
  }
else
  WD40_REPO=$(cd "$(dirname "$wd40_self")/../../.." && pwd -P) || {
    printf 'Error: cannot find this repository from %s\n' "$0" >&2
    exit 1
  }
fi
if [ ! -f "$WD40_REPO/manifest.toml" ]; then
  printf 'Error: %s has no manifest.toml, so it is not the dotfiles repository\n' "$WD40_REPO" >&2
  exit 1
fi

WD40_PLATFORM_NAME=${WD40_PLATFORM:-$(uname -s | tr '[:upper:]' '[:lower:]')}
WD40_TAB=$(printf '\t')
WD40_RECORDS=''

warn() { printf '! %s\n' "$*" >&2; }
die()  { printf 'Error: %s\n' "$1" >&2; exit "${2:-1}"; }

# --- manifest facts ----------------------------------------------------------
# Same field spec as install.sh and tests/check-symlinks.sh.
#
# Invoked via `python3` explicitly, not the file's own shebang/exec bit:
# WD40_ROOT (the test seam) can point under a sandbox that lands on a
# noexec-mounted /tmp (Docker's test containers do this), where direct
# execution fails even though the file is +x.
wd40_manifest() {
  python3 "$WD40_REPO/helpers/read-manifest.py" symlinks --format tsv \
    --fields "source,target,type:symlink,strip_ext:false,platform:" \
    --manifest "$WD40_REPO/manifest.toml"
}

# Expand a leading ~ in a manifest target.
wd40_expand() {
  case $1 in
    "~")   printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s%s\n' "$HOME" "${1#\~}" ;;
    *)     printf '%s\n' "$1" ;;
  esac
}

# THE strip rule (mirrors install.sh's strip_ext_name): a final .sh or .py
# suffix is removed — nothing else.
wd40_strip_name() {
  # wd40_strip_name BASENAME
  case $1 in
    *.sh) printf '%s\n' "${1%.sh}" ;;
    *.py) printf '%s\n' "${1%.py}" ;;
    *)    printf '%s\n' "$1" ;;
  esac
}

# Resolve a symlink chain to a physical path; fail on a cycle or a dangle.
# By hand, because readlink -f and realpath are GNU-only.
wd40_resolve() {
  # wd40_resolve PATH
  local _wd40_p=$1 _wd40_h=0 _wd40_l
  while [ -L "$_wd40_p" ] && [ "$_wd40_h" -lt 40 ]; do
    _wd40_l=$(readlink "$_wd40_p")
    case $_wd40_l in
      /*) _wd40_p=$_wd40_l ;;
      *)  _wd40_p=$(dirname "$_wd40_p")/$_wd40_l ;;
    esac
    _wd40_h=$((_wd40_h + 1))
  done
  [ -L "$_wd40_p" ] && return 1
  [ -e "$_wd40_p" ] || return 1
  (cd "$(dirname "$_wd40_p")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$_wd40_p")")
}

# 1 if DEST is a symlink resolving into this repo, else 0. Resolution-based
# ownership: a name is not evidence — somebody's own smem-groups on PATH is
# not this repository's install. These marks are informational, not a
# security boundary: whoever can repoint ~/.local/sbin/wd40 owns $HOME.
wd40_install_mark() {
  # wd40_install_mark DEST
  local dest=$1 target
  if [ -z "$dest" ] || [ ! -L "$dest" ]; then
    printf '0\n'
    return 0
  fi
  if target=$(wd40_resolve "$dest"); then
    case $target in
      "$WD40_REPO"/*) printf '1\n'; return 0 ;;
    esac
  fi
  printf '0\n'
}

wd40_usage() {
  cat <<'USAGE'
Usage: wd40 <command>

  list                list every command this repository provides
  help, -h, --help    show this help

list reads the repository's own files and manifest.toml, so the commands
are the same wherever it runs. Whether each is installed depends on this
machine: a missing one is marked with a leading `!`. Scripts are checked
against their ~/.local/sbin symlink; shell entries against the wd40rc
loader link (the mark means "the loader is installed", not "this file was
sourced by your current shell").
USAGE
}

wd40_no_args() {
  # wd40_no_args COMMAND [ARG...]
  local cmd=$1
  shift
  if [ $# -eq 0 ]; then
    return 0
  fi
  wd40_usage >&2
  die "wd40 $cmd takes no arguments (got '$1')" 1
}

# Print FILE's declarations, one per line: ok<TAB>NAME<TAB>DESCRIPTION, or
# bad<TAB>LINE<TAB>TEXT for a header line opening `wd40:` that is not a
# declaration. Only the HEADER is read — the run of blank and comment lines
# before the first line of code — so declaration-shaped strings in code can
# never be mistaken for declarations.
wd40_declaration_lines() {
  # wd40_declaration_lines FILE
  awk '
    $0 ~ /^[[:space:]]*$/ { next }
    $0 !~ /^[[:space:]]*#/ { exit }
    {
      body = $0
      sub(/^[[:space:]]*#+[[:space:]]*/, "", body)
      if (body !~ /^wd40:/) next
      sub(/^wd40:[[:space:]]*/, "", body)
      sub(/[[:space:]]+$/, "", body)

      # A name, a hyphen with space on both sides, and a description. The
      # hyphen must be a word of its own or smem-groups could not be named.
      if (!match(body, /^[^[:space:]]+[[:space:]]+-[[:space:]]+[^[:space:]]/)) {
        print "bad\t" NR "\t" $0
        next
      }
      match(body, /^[^[:space:]]+/)
      name = substr(body, 1, RLENGTH)
      sub(/^[^[:space:]]+[[:space:]]+-[[:space:]]+/, "", body)
      gsub(/\t/, " ", body)
      print "ok\t" name "\t" body
    }
  ' "$1"
}

# Turn one file into records. MODE strict: a file declaring nothing, or a
# script declaring a name the installer would not give it, dies — both are
# repository defects. MODE lenient (local/ only): the same findings warn
# and the run continues, because machine-local files are outside this
# repository's declaration pass.
wd40_collect() {
  # wd40_collect KIND FILE LINKNAME DEST MODE
  local kind=$1 file=$2 linkname=$3 dest=$4 mode=$5
  local what first rest declared=0 mark

  # Process substitution, not a pipe: a pipeline's `while read` body runs
  # in a subshell in bash 3.2, and a die in there would not stop the run.
  while IFS="$WD40_TAB" read -r what first rest; do
    [ -n "$what" ] || continue

    if [ "$what" = bad ]; then
      warn "$file, line $first, opens 'wd40:' and is not a declaration:"
      warn "  $rest"
      if [ "$mode" = lenient ]; then
        return 0
      fi
      die "a declaration reads: wd40: NAME - DESCRIPTION" 1
    fi

    declared=$((declared + 1))

    if [ "$kind" = scripts ] && [ "$mode" = strict ]; then
      if [ "$declared" -gt 1 ]; then
        die "$file declares more than one command, but a script is installed under one name" 1
      fi
      if [ "$first" != "$linkname" ]; then
        die "$file declares '$first', but the installer installs it as '$linkname'" 1
      fi
    fi

    mark=$(wd40_install_mark "$dest")
    WD40_RECORDS="$WD40_RECORDS$kind$WD40_TAB$first$WD40_TAB$mark$WD40_TAB$rest
"
  done < <(wd40_declaration_lines "$file")

  if [ "$declared" -eq 0 ]; then
    if [ "$mode" = lenient ]; then
      warn "$file declares no command (local files are exempt; a declaration reads: wd40: NAME - DESCRIPTION)"
      return 0
    fi
    die "$file declares no command; add a header line reading: wd40: NAME - DESCRIPTION" 1
  fi
}

# Print every command, grouped, aligned, missing ones marked `!`.
wd40_format() {
  awk '
    BEGIN { FS = "\t" }
    {
      kind[NR] = $1; name[NR] = $2; mark[NR] = $3; desc[NR] = $4
      if (length($2) > width) width = length($2)
      last = NR
    }
    END {
      label["scripts"] = "scripts"
      label["shell"]   = "shell functions"
      split("scripts shell", order, " ")

      printed = 0
      for (g = 1; g <= 2; g++) {
        k = order[g]
        any = 0
        for (i = 1; i <= last; i++) if (kind[i] == k) { any = 1; break }
        if (!any) continue

        if (printed) print ""
        printed = 1
        print label[k]

        for (i = 1; i <= last; i++) {
          if (kind[i] != k) continue
          printf "%s%-*s   %s\n", (mark[i] == "0" ? "! " : "  "), width, name[i], desc[i]
          if (mark[i] == "0") missing = 1
        }
      }
      if (missing) {
        print ""
        print "! not installed (run ./install.sh)"
      }
    }
  '
}

wd40_list() {
  wd40_no_args list "$@"

  local src tgt typ strip platform tgt_dir f base loader_link=''
  local sub mode manifest_tmp

  # wd40_manifest's output is read from a temp file, not process
  # substitution: bash 3.2 gives no way to see a `while read < <(cmd)`
  # pipeline's exit status through a plain $? (the read runs in the
  # foreground, but the command substitution's status is not the loop's),
  # so a manifest-read failure would otherwise look exactly like zero
  # records — silently. mktemp, check, then read: a failure dies loudly.
  manifest_tmp=$(mktemp) || die "cannot create a temp file to read the manifest" 1
  trap 'rm -f "$manifest_tmp"' EXIT
  if ! wd40_manifest > "$manifest_tmp"; then
    die "could not read $WD40_REPO/manifest.toml via helpers/read-manifest.py" 1
  fi

  # Scripts: every manifest glob entry sourced from wd40/, filtered to this
  # platform; plus the wd40rc entry, which tells us where the loader lands.
  while IFS="$WD40_TAB" read -r src tgt typ strip platform; do
    if [ "$src" = "wd40/wd40rc" ]; then
      loader_link=$(wd40_expand "$tgt")
      continue
    fi
    [ "$typ" = glob ] || continue
    case $src in
      wd40/*) ;;
      *) continue ;;
    esac
    if [ -n "$platform" ] && [ "$platform" != "$WD40_PLATFORM_NAME" ]; then
      continue
    fi
    tgt_dir=$(wd40_expand "${tgt%/\*}")
    for f in "$WD40_REPO"/$src; do
      [ -e "$f" ] || continue
      base=$(basename "$f")
      if [ "$strip" = true ]; then
        base=$(wd40_strip_name "$base")
      fi
      wd40_collect scripts "$f" "$base" "$tgt_dir/$base" strict
    done
  done < "$manifest_tmp"

  rm -f "$manifest_tmp"
  trap - EXIT

  # Shell: common → platform → local, same order the loader sources them.
  # An absent directory (local/ on a fresh checkout) is silently skipped.
  for sub in common "$WD40_PLATFORM_NAME" local; do
    [ -d "$WD40_REPO/wd40/$sub/shell" ] || continue
    mode=strict
    if [ "$sub" = local ]; then mode=lenient; fi
    for f in "$WD40_REPO/wd40/$sub/shell/"*.sh; do
      [ -e "$f" ] || continue
      wd40_collect shell "$f" "" "$loader_link" "$mode"
    done
  done

  # Discovery finding nothing means the repository was not found — this
  # file is itself one of the things it looks for.
  if [ -z "$WD40_RECORDS" ]; then
    die "no installable files under $WD40_REPO/wd40" 1
  fi

  printf '%s' "$WD40_RECORDS" | wd40_format
}

# A bare `wd40` is a question, not a mistake: usage on stdout, exit 0.
if [ $# -eq 0 ]; then
  wd40_usage
  exit 0
fi

wd40_command=$1
shift

case $wd40_command in
  list)
    wd40_list "$@" ;;
  help|-h|--help)
    wd40_no_args "$wd40_command" "$@"
    wd40_usage ;;
  *)
    wd40_usage >&2
    die "unknown argument '$wd40_command'" 1 ;;
esac
