# Secure Input Watcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Hammerspoon module that notifies when a background app has held macOS Secure Event Input for ~2 minutes, tracked in this repo and symlinked into `~/.hammerspoon`.

**Architecture:** `config/hammerspoon/init.lua` loads `secure_input_watch.lua`. The module keeps its decision logic in two pure functions (`parse_holder_pid`, `step`) so it can be tested, and a thin `start()`/`stop()` shell that owns an `hs.timer` and calls `hs.notify`. Tests run inside the live Hammerspoon through the `hs` CLI.

**Tech Stack:** Lua (Hammerspoon 1.1.1: `hs.timer`, `hs.eventtap`, `hs.application`, `hs.notify`, `hs.ipc`), bash test scripts using `tests/helpers.sh`.

**Spec:** `docs/superpowers/specs/2026-10-25-secure-input-watch-design.md`

## Global Constraints

- Tick every 30s; notify at 4 consecutive ticks (~2 min) with the same holder PID.
- Notify only when the holder is not the frontmost app; one notification per holding episode.
- Notify only. Never quit or restart any app.
- Holder PID source: `kCGSSessionSecureInputPID` from `/usr/sbin/ioreg -l -w0`. Held/not-held source: `hs.eventtap.isSecureInputEnabled()`.
- Symlink via one `type = "glob"`, `platform = "darwin"` manifest entry: `config/hammerspoon/*` -> `~/.hammerspoon/*`. The existing `~/.hammerspoon/Spoons/` must be left alone.
- Not committed unless the user asks (working tree has unrelated uncommitted files). Steps below say "checkpoint" where the repo would normally commit; do not run `git commit`.
- Plan call (not in spec): `init.lua` also does `require("hs.ipc")` so the `hs` CLI can drive verification.

## Review Focus

- `ioreg` output with several `kCGSSessionSecureInputPID` matches: use the first. (Task 2)
- Secure Input on but PID unreadable/absent in `ioreg` output: no notification, no error, streak resets. (Task 2)
- Holder changes between ticks (A releases, B grabs): B's streak starts at 1 and B gets its own notification. (Task 2)
- Holder is frontmost for a long time then goes to the background: streak starts at that point, not before. (Task 2)
- Released and re-held later: notifies again. (Task 2)
- Holder PID no longer resolves to an app: message falls back to "PID <n>", no Lua error. (Task 3)
- `start()` called twice (config reload): only one timer remains. (Task 3)

---

### Task 1: Bootstrap config, symlink and `hs` CLI

**Files:**
- Create: `config/hammerspoon/init.lua`
- Modify: `manifest.toml` (add after the `config/herdr/config.toml` symlink entry)
- Test: `tests/check-symlinks.sh` (existing, reads the manifest)

**Interfaces:**
- Produces: a running Hammerspoon with `hs.ipc` loaded, so `hs -A -q -t 5 -c '<lua>'` and `hs -A -q -t 5 /abs/file.lua` work. Later tasks rely on this.

- [x] **Step 1: Confirm the baseline is red.** Run `ls ~/.hammerspoon/init.lua`. Expected: `No such file or directory`.
- [x] **Step 2: Create `config/hammerspoon/init.lua`** containing only `require("hs.ipc")` and a one-line comment saying it enables the `hs` CLI.
- [x] **Step 3: Add to `manifest.toml`** a `[[symlinks]]` entry with `source = "config/hammerspoon/*"`, `target = "~/.hammerspoon/*"`, `type = "glob"`, `platform = "darwin"`, matching the style of the neighbouring entries.
- [x] **Step 4: Apply it.** Run `./install.sh --no-install-deps`. Expected: `~/.hammerspoon/init.lua` is a symlink into the repo; `~/.hammerspoon/Spoons` still exists. Verify with `ls -la ~/.hammerspoon`.
- [x] **Step 5: Restart Hammerspoon and verify the CLI.** Run `osascript -e 'quit app "Hammerspoon"'; sleep 2; open -a Hammerspoon; sleep 3` (Hammerspoon has no config today, so nothing is lost), then `hs -A -q -t 5 -c '1+1'`. Expected: prints `2`.
- [x] **Step 6: Verify symlink check.** Run `./tests/check-symlinks.sh`. Expected: a `✓` line for `~/.hammerspoon/init.lua` and no `✗`.
- [x] **Step 7: Checkpoint** (no commit): `git status --short config manifest.toml` shows exactly the two intended paths.

---

### Task 2: Pure decision logic and its tests

**Files:**
- Create: `config/hammerspoon/secure_input_watch.lua`
- Create: `tests/hammerspoon/secure_input_watch_test.lua`
- Create: `tests/check-hammerspoon.sh`
- Modify: `test.sh` (add `"$SCRIPT_DIR/tests/check-hammerspoon.sh" || rc=1` after the `test-install-cronjobs.sh` line)

**Interfaces:**
- Produces, from `secure_input_watch.lua` (returns table `M`):
  - `M.TICK_SECONDS = 30`, `M.THRESHOLD_TICKS = 4`
  - `M.parse_holder_pid(ioreg_output: string): integer|nil` returns the first `"kCGSSessionSecureInputPID"=<digits>` value, else nil.
  - `M.new_state(): {pid: integer|nil, ticks: integer, notified: boolean}` returns `{pid=nil, ticks=0, notified=false}`.
  - `M.step(state, sample): newState, notify` where `sample = {pid: integer|nil, frontmost_pid: integer|nil}`. Rules: `pid == nil` or `pid == frontmost_pid` -> `new_state(), false`. Same pid as `state.pid` -> `ticks + 1`; different pid -> `{pid=pid, ticks=1, notified=false}`. `notify` is true only when `ticks >= THRESHOLD_TICKS` and not already notified; then `notified = true`. `step` must not mutate its input.
- Consumes (test file): `dofile(<repo>/config/hammerspoon/secure_input_watch.lua)`; the repo path comes from `_cli.args[1]`.

- [x] **Step 1: Write the failing tests** in `tests/hammerspoon/secure_input_watch_test.lua`. It loads the module, runs plain `assert`s, and ends with `return "ok"`. Cases (names as comments or labels on assert messages):
  - `parse_holder_pid` returns `82360` for `'... "kCGSSessionSecureInputPID"=82360, ...'`; nil for `''` and for output without the key; `111` when two matches (`...=111 ... =222`) are present.
  - `step`: three ticks `{pid=5, frontmost_pid=9}` -> notify false each, `ticks == 3`; fourth -> notify true; fifth -> notify false (once per episode).
  - `step`: `pid=nil` after a streak -> state equals `new_state()`, notify false, then a new held episode of 4 ticks notifies again.
  - `step`: holder changes 5 -> 6 at tick 3 -> `ticks == 1`, `pid == 6`; 6 reaches its own notify after 4 ticks.
  - `step`: `pid == frontmost_pid` for 10 ticks -> never notifies, `ticks == 0`; then goes to the background: first background tick has `ticks == 1`.
  - `step` does not mutate the table passed in.
- [x] **Step 2: Write `tests/check-hammerspoon.sh`** using `tests/helpers.sh` like `check-symlinks.sh` (`section "Hammerspoon"`, `pass`/`fail`/`warn`). Darwin-only: on other platforms `warn` and exit 0. If `hs` is not on PATH or `hs -A -q -t 5 -c '1'` fails, `warn "Hammerspoon CLI unavailable, skipped"` and exit 0. Otherwise run `hs -A -q -t 5 <repo>/tests/hammerspoon/secure_input_watch_test.lua <repo>` and `pass` if output is `ok`, else `fail` with the output.
- [x] **Step 3: Run it to confirm it fails.** `chmod +x tests/check-hammerspoon.sh && ./tests/check-hammerspoon.sh`. Expected: `✗` (module file does not exist yet).
- [x] **Step 4: Implement the pure part of `secure_input_watch.lua`** per the Interfaces block (`M.TICK_SECONDS`, `M.THRESHOLD_TICKS`, `M.parse_holder_pid`, `M.new_state`, `M.step`). Use `string.match(output, '"kCGSSessionSecureInputPID"=(%d+)')` and `tonumber`.
- [x] **Step 5: Run it to confirm it passes.** `./tests/check-hammerspoon.sh`. Expected: `✓` and no `✗`.
- [x] **Step 6: Wire into `test.sh`** as described under Files, then run `bash -n test.sh`. Expected: no output.
- [x] **Step 7: Checkpoint** (no commit).

---

### Task 3: Timer, notification and `init.lua` wiring

**Files:**
- Modify: `config/hammerspoon/secure_input_watch.lua` (add the I/O shell below the pure part)
- Modify: `config/hammerspoon/init.lua`
- Modify: `tests/hammerspoon/secure_input_watch_test.lua` (shell-level cases)

**Interfaces:**
- Consumes: `M.step`, `M.new_state`, `M.parse_holder_pid`, `M.TICK_SECONDS` from Task 2.
- Produces:
  - `M.message(app_name: string, seconds: integer): string`, e.g. `"Dia has held Secure Input for 120s. Option hotkeys (Raycast) are blocked. Restart Dia."`
  - `M.tick(deps: table|nil)`: runs one tick. `deps` optionally overrides `{secure_enabled=function():boolean, ioreg=function():string, frontmost_pid=function():integer|nil, app_name=function(pid:integer):string|nil, notify=function(msg:string)}` so tests can stub I/O; defaults use `hs.eventtap.isSecureInputEnabled`, `hs.execute("/usr/sbin/ioreg -l -w0")`, `hs.application.frontmostApplication():pid()`, `hs.application.applicationForPID(pid):name()`, and `hs.notify.new({title="Secure Input held", informativeText=msg, withdrawAfter=0}):send()`. If `app_name` returns nil use `"PID " .. pid`. `ioreg` is only called when `secure_enabled()` is true.
  - `M.start(): hs.timer` stops any existing timer, resets state, and creates `hs.timer.doEvery(M.TICK_SECONDS, M.tick)` held in a module-level variable. `M.stop()` stops and clears the timer and resets the state to `new_state()`.
- `init.lua` becomes: `require("hs.ipc")` plus `require("secure_input_watch").start()` (Hammerspoon's `package.path` includes `~/.hammerspoon`).

- [x] **Step 1: Add failing test cases** to the test file using stubbed `deps`. `tick` is stateful, so `M.stop()` also resets the module's state to `new_state()`; the tests call `M.stop()` before each case. Cases:
  - Secure input off: 10 ticks -> notify never called and `ioreg` stub never called.
  - Held by pid 5, frontmost 9, `app_name` returns `"Dia"`: after 4 ticks notify called exactly once with `M.message("Dia", 120)`.
  - `app_name` returns nil: message contains `"PID 5"`.
  - `ioreg` stub returns output without the key while secure is on: 10 ticks, no notify, no error.
  - `M.start()` twice: `hs.timer.running` count check — keep a reference from the first call; after the second call the first is no longer `:running()`.
- [x] **Step 2: Run to confirm failure.** `./tests/check-hammerspoon.sh`. Expected: `✗` (functions missing).
- [x] **Step 3: Implement `M.message`, `M.tick`, `M.start`, `M.stop`** per Interfaces. `tick` builds the sample (`pid` from `parse_holder_pid` only when secure input is on; `frontmost_pid` from deps), calls `step`, stores the new state in a module-level variable, and on `notify` calls `deps.notify(M.message(name, M.THRESHOLD_TICKS * M.TICK_SECONDS))`.
- [x] **Step 4: Update `init.lua`** as described under Interfaces.
- [x] **Step 5: Reload the config** with `hs -A -q -t 5 -c 'hs.reload()'`, wait 2s, then check it loaded: `hs -A -q -t 5 -c 'return tostring(package.loaded["secure_input_watch"] ~= nil)'`. Expected: `true`.
- [x] **Step 6: Run to confirm pass.** `./tests/check-hammerspoon.sh`. Expected: `✓`, no `✗`.
- [x] **Step 7: Live check, real world.** With nothing holding Secure Input: `ioreg -l -w0 | grep -c kCGSSessionSecureInputPID` -> `0` and no notification arrives in 3 minutes of watching. Then `hs -A -q -t 5 -c 'require("secure_input_watch").tick({secure_enabled=function() return true end, ioreg=function() return "\"kCGSSessionSecureInputPID\"=1" end, frontmost_pid=function() return 2 end, app_name=function() return "Test" end, notify=hs.alert.show})'` four times; expected: on the fourth, an on-screen alert with the "Test has held..." message.
- [x] **Step 8: Checkpoint** (no commit): `git status --short config tests manifest.toml test.sh docs`.

---

## Self-Review

- **Spec coverage:** tick interval/threshold (Task 2 constants, Task 3 timer), frontmost exclusion and once-per-episode (Task 2 `step`), `ioreg` PID + `isSecureInputEnabled` (Task 3 `tick`), notification wording naming the app (Task 3 `message`), glob symlink leaving `Spoons/` alone (Task 1), notify-only (no quit anywhere), not committed (Global Constraints). Spec's "verification" list maps to Tasks 1, 3 steps 5-7, and `check-symlinks.sh`.
- **Types:** `step`/`new_state`/`parse_holder_pid` names and the `sample`/`state` shapes are identical in Tasks 2 and 3; `message(app_name, seconds)` is called with `THRESHOLD_TICKS * TICK_SECONDS`.
- **Review Focus:** each line is covered by a Task 2 or Task 3 test case.
