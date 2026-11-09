#!/bin/bash
#
# cpu-groups.sh - list top CPU-consuming process groups, grouped by root ancestor.
#
# wd40: cpu-groups - list top CPU consumers grouped by their root ancestor process
#
# `ps`/`top` show one line per process, which turns one build job into
# dozens of unrelated-looking `java`/`javac`/`ninja` lines. This script
# walks every process's parent chain up to its root ancestor (PID 1 by
# default, or a shallower stop via --depth), sums %CPU/%MEM per root and
# shows the top N groups - so "docker run ... build" shows up as one
# group with 47 member PIDs instead of 47 separate lines.
#
# %CPU is `ps`'s pcpu: CPU time / elapsed time over each process's WHOLE
# life, not a recent window, divided here by the core count so the column
# sums to at most 100. A long-idle daemon that once burned CPU still shows
# it; use `top` for what is hot this second.
#
# Usage:
#   ./cpu-groups.sh                  # top 10 groups, all users
#   ./cpu-groups.sh -n 20            # top 20 groups
#   ./cpu-groups.sh -u jfujiok       # only this user's processes
#   ./cpu-groups.sh -d 3             # stop climbing after 3 hops
#   ./cpu-groups.sh -s mem           # sort groups by %MEM instead of %CPU
#
# Exit codes: 1 = invalid argument.

set -euo pipefail

TOP_N=10
FILTER_USER=""
MAX_DEPTH=""
SORT_SPEC="cpu"

usage() {
  cat <<'USAGE'
Usage: cpu-groups.sh [options]

  -n N             Top N groups to show (default: 10)
  -u USER          Only this user's processes (default: all users)
  -d, --depth N    Max hops to climb toward the root ancestor
                   (default: unlimited, i.e. climb to PID 1)
  -s, --sort SPEC  Sort key: cpu, mem, name (default: cpu)
  -h               Show this help
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -n)
      [ $# -ge 2 ] || { echo "Error: -n requires an argument" >&2; exit 1; }
      case "$2" in
        ''|*[!0-9]*)
          echo "Error: -n requires a positive integer (got '$2')" >&2
          exit 1 ;;
      esac
      [ "$2" -gt 0 ] || { echo "Error: -n requires a positive integer (got '$2')" >&2; exit 1; }
      TOP_N="$2"; shift 2 ;;
    -u)
      [ $# -ge 2 ] || { echo "Error: -u requires an argument" >&2; exit 1; }
      FILTER_USER="$2"; shift 2 ;;
    -d|--depth)
      [ $# -ge 2 ] || { echo "Error: $1 requires an argument" >&2; exit 1; }
      case "$2" in
        ''|*[!0-9]*)
          echo "Error: $1 requires a positive integer (got '$2')" >&2
          exit 1 ;;
      esac
      MAX_DEPTH="$2"; shift 2 ;;
    -s|--sort)
      [ $# -ge 2 ] || { echo "Error: $1 requires an argument" >&2; exit 1; }
      SORT_SPEC="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Error: unknown argument '$1'" >&2
      usage >&2
      exit 1 ;;
  esac
done

case "$SORT_SPEC" in
  cpu|mem|name) ;;
  *)
    echo "Error: unknown sort key '$SORT_SPEC'. Valid keys: cpu, mem, name" >&2
    exit 1 ;;
esac

# WHY -e VS -A: GNU ps (Linux) accepts -e for "every process". BSD ps
# (macOS/Darwin) does not recognize -e and requires -A instead. Both accept
# the same -o field-list syntax, so detecting the right "all processes"
# flag is the only branch needed - same portability shape as
# smem-groups.sh's -U passthrough, but decided once here instead of at
# every call site.
ps_all_flag() {
  if ps -e >/dev/null 2>&1; then
    printf '%s\n' "-e"
  else
    printf '%s\n' "-A"
  fi
}

# Prints "PID PPID PCPU PMEM ARGS" - one line per process, snapshotted once.
# ARGS is always the last column so it can hold spaces. Do not add `comm`:
# it can contain spaces too ("tmux: server"), which makes the split ambiguous.
#
# LC_ALL=C: pcpu/pmem use the locale's decimal separator; a comma would make
# awk read 3,5 as 3.
#
# With -u, `-U` is used INSTEAD of -e/-A: ps ORs selection options, so
# `ps -e -U user` still lists every process.
ps_snapshot() {
  if [ -n "$FILTER_USER" ]; then
    LC_ALL=C ps -U "$FILTER_USER" -o pid=,ppid=,pcpu=,pmem=,args= 2>/dev/null || true
  else
    LC_ALL=C ps "$(ps_all_flag)" -o pid=,ppid=,pcpu=,pmem=,args=
  fi
}

# Reads "PID PPID PCPU PMEM ARGS" from stdin (one ps_snapshot line per
# process) and prints one line per root-ancestor group:
#   ROOT_PID  TOTAL_CPU  TOTAL_MEM  MEMBER_COUNT  MEMBER_PIDS  ROOT_CMD
# tab-separated, sorted per SORT_SPEC, capped at TOP_N groups, with a final
# TOTAL line over ALL groups (not just the shown ones). MAX_DEPTH (empty =
# unlimited) caps how many PPID hops the walk takes before it stops and uses
# whatever PID it last reached as the root.
group_by_root() {
  local ncpu="${1:-1}"
  LC_ALL=C awk -v top_n="$TOP_N" -v max_depth="$MAX_DEPTH" -v sort_spec="$SORT_SPEC" -v ncpu="$ncpu" '
    {
      pid = $1; ppid = $2; pcpu = $3; pmem = $4
      # ARGS (field 5 onward) may contain spaces; rebuild it from the rest
      # of the line instead of relying on a fixed field count.
      args = ""
      for (i = 5; i <= NF; i++) args = (i == 5) ? $i : args " " $i

      PPID_OF[pid] = ppid
      CMD_OF[pid] = args
      CPU_OF[pid] = pcpu
      MEM_OF[pid] = pmem
      ORDER[++n] = pid
    }
    END {
      # Attribute EVERY process to its root, so a group'"'"'s %CPU, %MEM and N
      # are complete; only the printed list is capped at top_n below.
      for (i = 1; i <= n; i++) {
        pid = ORDER[i]
        root = pid
        depth = 0
        while (1) {
          if (max_depth != "" && depth >= max_depth) break
          parent = PPID_OF[root]
          if (parent == "" || parent == root) break
          if (!(parent in CMD_OF)) break
          if (parent == 1) break
          root = parent
          depth++
        }
        if (!(root in SEEN)) {
          SEEN[root] = 1
          ROOT_LIST[++g] = root
          ROOT_CMD[root] = CMD_OF[root]
        }
        ROOT_CPU[root] += CPU_OF[pid] / ncpu
        ROOT_MEM[root] += MEM_OF[pid]
        ROOT_N[root]++
        ROOT_MEMBERS[root] = (ROOT_MEMBERS[root] == "" \
          ? pid : ROOT_MEMBERS[root] "," pid)
        TOTAL_CPU += CPU_OF[pid] / ncpu
        TOTAL_MEM += MEM_OF[pid]
        TOTAL_N++
      }

      # Sort the g groups per sort_spec ("cpu", "mem", or "name"). Insertion
      # sort: no asort() (gawk-only, absent on BSD awk/macOS).
      for (i = 1; i <= g; i++) GSEL[i] = ROOT_LIST[i]
      for (i = 2; i <= g; i++) {
        key = GSEL[i]
        if (sort_spec == "mem") { keyval = ROOT_MEM[key] + 0 }
        else if (sort_spec == "name") { keyval = ROOT_CMD[key] }
        else { keyval = ROOT_CPU[key] + 0 }
        j = i - 1
        while (j >= 1) {
          if (sort_spec == "name") {
            cmp = (ROOT_CMD[GSEL[j]] > keyval)
          } else {
            cmpval = (sort_spec == "mem") ? ROOT_MEM[GSEL[j]] + 0 : ROOT_CPU[GSEL[j]] + 0
            cmp = (cmpval < keyval)
          }
          if (!cmp) break
          GSEL[j+1] = GSEL[j]; j--
        }
        GSEL[j+1] = key
      }

      show = (top_n < g) ? top_n : g
      for (i = 1; i <= show; i++) {
        r = GSEL[i]
        printf "%s\t%.1f\t%.1f\t%d\t%s\t%s\n", \
          r, ROOT_CPU[r], ROOT_MEM[r], ROOT_N[r], ROOT_MEMBERS[r], ROOT_CMD[r]
      }
      printf "TOTAL\t%.1f\t%.1f\t%d\t-\t-\n", TOTAL_CPU, TOTAL_MEM, TOTAL_N
    }
  '
}

# Formats group_by_root's tab-separated lines into an aligned table.
# MEMBER_PIDS is truncated to the first 8 entries plus "..." if there are
# more, so one group with 47 members doesn't blow out the line width - the
# true count is always in the N column regardless of truncation.
format_groups() {
  local cols="${1:-120}"
  awk -F'\t' -v cols="$cols" '
    function truncate_pids(pids,    parts, i, count, out) {
      count = split(pids, parts, ",")
      if (count <= 8) return pids
      out = ""
      for (i = 1; i <= 8; i++) out = (i == 1) ? parts[i] : out "," parts[i]
      return out ",..."
    }
    function repeat(ch, n,    s, i) {
      s = ""
      for (i = 0; i < n; i++) s = s ch
      return s
    }
    BEGIN {
      fixed = 7 + 1 + 6 + 1 + 4 + 2
      cmd_w = cols - fixed - 20
      if (cmd_w < 20) cmd_w = 20
      fmt = "%-" cmd_w "s %7s %6s %4s  %s\n"
      printf fmt, "ROOT CMD", "%CPU", "%MEM", "N", "PIDS"
    }
    {
      root = $1; cpu = $2; mem = $3; n = $4; members = $5; cmd = $6
      if (root == "TOTAL") {
        printf fmt, repeat("-", cmd_w), "-------", "------", "----", "----"
        printf fmt, "TOTAL", sprintf("%.1f", cpu), sprintf("%.1f", mem), n, "-"
        next
      }
      display_cmd = cmd
      if (length(display_cmd) > cmd_w) display_cmd = substr(display_cmd, 1, cmd_w - 3) "..."
      printf fmt, display_cmd, sprintf("%.1f", cpu), sprintf("%.1f", mem), n, truncate_pids(members)
    }
  '
}

main() {
  snapshot="$(ps_snapshot)"
  count="$(printf '%s\n' "$snapshot" | grep -c . || true)"
  if [ "$count" -eq 0 ]; then
    if [ -n "$FILTER_USER" ]; then
      echo "No processes found for user '$FILTER_USER'."
    else
      echo "No processes found."
    fi
    exit 0
  fi
  ncpu="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)"
  cols="$(tput cols 2>/dev/null || echo 120)"
  printf '%s\n' "$snapshot" | group_by_root "$ncpu" | format_groups "$cols"
}

main
