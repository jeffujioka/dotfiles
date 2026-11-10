# Dotfiles

Personal machine setup: shell environment, tool configuration, and how local tools are wired together.

## OpenCode

**Shared server**:
The single OpenCode server that both OpenChamber and the OpenCode CLI attach to, so they see the same sessions.
_Avoid_: OpenChamber server, main server, remote server

**Standalone run**:
An OpenCode CLI invocation that uses its own private server instead of the shared server.
_Avoid_: local run, direct run

**Background service**:
OpenCode's built-in long-running server, managed with `opencode service`.
_Avoid_: daemon, opencode service server

## Scheduling

**Scheduled job**:
A task that runs on a timetable with no terminal attached, so it cannot prompt and has none of the interactive shell's environment.
_Avoid_: cron job, timer

## Terminal

**Herdr**:
The terminal multiplexer that organises panes, tabs and workspaces, and supervises coding agents. It replaced tmux.
_Avoid_: tmux, multiplexer (unqualified)

**Workspace**:
A Herdr container of tabs and panes, used to keep one project's terminals together.
_Avoid_: session (that was the tmux term)

## Clipboard

**Clipboard bridge**:
The path that carries text copied on a remote Linux host to the Mac clipboard: the SSH reverse tunnel, the Mac listener, and the Linux-side `pbcopy`.
_Avoid_: clipboard tunnel, pbcopy shim

## Installation

**Script installer**:
A tool installed by running the vendor's own install script instead of a package manager.
_Avoid_: curl-bash, curl pipe

## Tool versions

**Global tool versions**:
The versions of each asdf-managed tool that apply everywhere no repo says otherwise, kept in the untracked `~/.tool-versions` and moved to the newest release automatically.
_Avoid_: default versions, system versions

**Repo pin**:
A version a repo fixes for itself in its own `.tool-versions`; it wins over the global tool versions inside that repo and is never changed by this setup.
_Avoid_: local version, project version

**Node owner**:
The one tool allowed to put `node` on the `PATH`. It is asdf; nvm and Homebrew's `node` are not used.
_Avoid_: node manager (unqualified)
