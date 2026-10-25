# Secure Input watcher (Hammerspoon)

## Intent

On 2026-10-25 Dia held macOS Secure Event Input for ~9h40m while in the
background. While it is held, macOS blocks global hotkeys whose only modifier
is Option (or Option+Shift), so Raycast's "option <key>" hotkeys silently
stopped working. The cause was only found by hand with `ioreg`.

Tell the user, with a notification, when a background app is holding Secure
Input, naming the app, so the fix (restart that app) is obvious.

## Goals

- Notification naming the holder app when a background app has held Secure
  Input for about 2 minutes.
- One notification per holding episode; resets when the lock is released.
- Config tracked in this repo and symlinked like the other tools.

## Non-goals

- Quitting or restarting the offending app (notify only, for now).
- Finding out *why* the app grabbed Secure Input (Dia blocks JS probing).
- Notifying when the holder is the frontmost app (that is normal password entry).
- Menubar indicator or clickable actions.
- Auto-reloading Hammerspoon on config change.

## Constraints

- `~/.hammerspoon` exists with only an empty `Spoons/`; no `init.lua` anywhere
  in the repo today.
- Hammerspoon 1.1.1 provides `hs.eventtap.isSecureInputEnabled()` (boolean, no
  PID). The holder PID comes from `ioreg`: `kCGSSessionSecureInputPID`.
- Hammerspoon is already installed and running; it is not in `manifest.toml`.

## Approaches

1. launchd agent + shell script in `wd40/darwin/cronjobs/`. Fits the existing
   Scheduled job pattern, no new tool config.
2. **Hammerspoon `init.lua` module (chosen by the user).** Heavier, since the
   repo starts managing Hammerspoon config, but leaves room for a menubar item
   or a "restart app" action later.

## Design

Files:

- `config/hammerspoon/init.lua`: loads the module.
- `config/hammerspoon/secure_input_watch.lua`: the watcher.
- `manifest.toml`: one glob symlink
  `config/hammerspoon/*` -> `~/.hammerspoon/*` (`type = "glob"`,
  `platform = "darwin"`), so the existing `Spoons/` is left alone.

Behaviour of the watcher:

- An `hs.timer` ticks every 30s.
- If `hs.eventtap.isSecureInputEnabled()` is false: clear state, done.
- Otherwise read the holder PID from `ioreg -l -w0`, resolve it with
  `hs.application.applicationForPID` (fall back to the PID if it cannot be
  resolved).
- If the holder is the frontmost app, or the PID cannot be read: reset the
  streak.
- Otherwise count consecutive ticks with the same PID. At 4 ticks (~2 min),
  send one `hs.notify` such as "Dia has held Secure Input for 2 min. Option
  hotkeys (Raycast) are blocked. Restart Dia." and mark the PID as notified.
- The timer is held in a module-level variable so it is not garbage collected.

## Left to the builder

- Exact wording and notification identifiers.
- Splitting parsing/decision logic into a pure function that can be checked
  without Hammerspoon, if cheap.

## My calls (not yet confirmed by the user)

- 30s tick, 4 ticks (~2 min) threshold.
- Notification only fires when the holder is not frontmost.
- Glob symlink into the existing `~/.hammerspoon` rather than replacing the
  directory.
- Not committed: the working tree already has unrelated uncommitted files.

## Verification

- Hammerspoon console shows no load errors after `hs.reload()`.
- With Secure Input not held: no notification.
- Simulated holder (stub the `ioreg` output / threshold in the console): one
  notification, and none repeated until released and re-held.
- `tests/check-symlinks.sh` passes with the new manifest entry.
