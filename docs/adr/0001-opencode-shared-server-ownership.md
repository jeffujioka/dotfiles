# OpenChamber owns the OpenCode shared server; the CLI attaches opt-in via `occ`

OpenChamber and the OpenCode CLI need a shared server to see the same sessions. OpenChamber starts and owns it (`127.0.0.1:5555`). Plain `opencode` is left untouched and uses its own background service; attaching is an explicit choice through the `occ` alias (`opencode_chamber` in `wd40/darwin/shell/opencode.sh`), which fails loudly when OpenChamber isn't running.

## Considered Options

- **OpenCode's background service as the shared server, OpenChamber attached via `OPENCODE_HOST`.** Cleanest CLI, rejected because OpenChamber disables its Agent Control Tool (and browser tool) when connected to an external server.
- **A `PATH` wrapper script (`~/.local/sbin/opencode`) redirecting every `opencode` call.** The previous approach; replaced because it intercepted every caller and mis-routed subcommands such as `service … --standalone`.
- **A zsh `opencode()` function shadowing the binary.** Rejected in favour of a separate name so the real binary's behaviour is never surprising.

## Consequences

Sessions started with plain `opencode` live on the background service and do not appear in OpenChamber.
