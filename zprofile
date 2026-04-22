#!/usr/bin/zsh
# Environment variables that must be visible to ALL processes —
# login shells, VS Code Server, Gradle daemons, tmux server, etc.
# Sourced by: ~/.zprofile (zsh login) and ~/.profile (bash login).

export TMPDIR="$HOME/.local/tmp"
mkdir -p "$TMPDIR"

export TMUX_TMPDIR="$HOME/.config/tmux/tmp"
mkdir -p "$TMUX_TMPDIR"

export HOMEBREW_TEMP="$HOME/.local/brew/tmp"
mkdir -p "$HOMEBREW_TEMP"

# Java ignores TMPDIR — must set java.io.tmpdir explicitly.
# Covers Gradle daemons, Kotlin compile daemon, VS Code Java LSP.
export JAVA_TOOL_OPTIONS="-Djava.io.tmpdir=$HOME/.local/tmp"
