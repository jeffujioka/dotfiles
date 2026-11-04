# wd40

Shell tooling for this dotfiles repo: scripts installed onto `PATH` and
functions/aliases sourced into the shell. Named after the old standalone
repo it absorbed ("If it moves and it shouldn't: duct tape. If it doesn't
move and it should: WD-40.").

## Layout

    wd40rc                     entrypoint sourced by ~/.zshrc and ~/.bashrc
    common/   scripts/ shell/  every platform
    darwin/   scripts/ shell/  macOS only
    linux/    scripts/ shell/  Linux only
    local/    shell/           THIS machine only — gitignored, never committed

`scripts/` files are symlinked into `~/.local/sbin` by the repo's
`./install.sh` (driven by `manifest.toml`), with a final `.sh`/`.py`
stripped from the installed name. `shell/` files are sourced by `wd40rc`:
`common` → `<platform>` → `local`, alphabetical within each directory.

## Discovery

    wd40 list

lists every command, `!`-marking ones whose install link is missing. Every
tracked file must declare what it provides in its header:

    # wd40: NAME - DESCRIPTION

Scripts declare exactly one NAME equal to their installed name. Shell files
declare each public (non-`_`-prefixed) function; alias-only files declare
one group label. Files under `local/` are exempt (warned, never fatal).

## Adding a command

1. Drop the file in the right `<platform>/scripts/` or `<platform>/shell/`.
2. Add the `# wd40:` declaration header.
3. Scripts: nothing else — the manifest globs pick it up on next install.
4. Run `wd40 list` and `wd40/test/smoke.sh`.

New wd40-native bash files (this directory's own tooling, not absorbed
scripts) must pass the bash 3.2 / BSD portability guard in
`wd40/test/smoke.sh` — add them to its file list.

## Clipboard bridge

On a remote Linux box, `pbcopy` (`linux/scripts/pbcopy`) sends stdin to the
Mac clipboard through an SSH reverse tunnel, and falls back to the local
clipboard (`wl-copy`, `xclip`, `xsel`) when nothing is listening. It does
not depend on `SSH_*` variables, so panes that outlived their ssh session
still work. Needs `netcat-openbsd`. `WD40_PBCOPY_PORT` overrides 2224.

The Mac side is not in this repo: a launchd agent labelled
`localhost.pbcopy` listens on 127.0.0.1:2224 (inetd-style, one process per
connection) and runs `pbcopy-launchd`, which `exec`s `/usr/bin/pbcopy`
with a UTF-8 locale. The ssh host entry needs
`RemoteForward 2224 localhost:2224`. Because the listener spawns per
connection, never probe the port (`nc -z`): a bare connect clears the Mac
clipboard.

## Tests

    wd40/test/smoke.sh          # standalone
    ./test.sh sanity-check      # runs it via tests/check-wd40.sh
