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
