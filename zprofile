#!/usr/bin/zsh
# Environment variables that must be visible to ALL processes —
# login shells, VS Code Server, Gradle daemons, etc.
# Sourced by: ~/.zprofile (zsh login) and ~/.profile (bash login).

export TMPDIR="$HOME/.local/tmp"
mkdir -p "$TMPDIR"

export HOMEBREW_TEMP="$HOME/.local/brew/tmp"
mkdir -p "$HOMEBREW_TEMP"

# Java ignores TMPDIR — must set java.io.tmpdir explicitly.
# Covers Gradle daemons, Kotlin compile daemon, VS Code Java LSP.
export JAVA_TOOL_OPTIONS="-Djava.io.tmpdir=$HOME/.local/tmp"

# OpenChamber: fixed port and password for its managed OpenCode server.
# OpenChamber imports them through its login-shell probe on every launch
# (Dock, auto-update relaunch, login). Scoped to OpenChamber's own shells.
if [[ "${__CFBundleIdentifier:-}" == dev.openchamber.desktop ]]; then
  export OPENCHAMBER_OPENCODE_PORT=5555
  export OPENCODE_SERVER_PASSWORD="$(security find-generic-password -s openchamber-opencode -w 2>/dev/null)"
fi
