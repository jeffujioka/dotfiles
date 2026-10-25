local repo = _cli.args[2]
local M = dofile(repo .. "/config/hammerspoon/secure_input_watch.lua")

local function eq(actual, expected, msg)
    assert(actual == expected, msg .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

eq(M.TICK_SECONDS, 30, "tick interval")
eq(M.THRESHOLD_TICKS, 4, "threshold ticks")

-- parse_holder_pid
local ioreg_one = '{ "kCGSSessionUserNameKey"="x", "kCGSSessionSecureInputPID"=82360, "other"=1 }'
eq(M.parse_holder_pid(ioreg_one), 82360, "parse single PID")
eq(M.parse_holder_pid(""), nil, "parse empty output")
eq(M.parse_holder_pid('{ "other"=1 }'), nil, "parse output without key")
eq(M.parse_holder_pid('"kCGSSessionSecureInputPID"=111, "kCGSSessionSecureInputPID"=222'), 111, "parse first of two matches")

-- step: streak and once-per-episode notify
local s = M.new_state()
local notify
for i = 1, 3 do
    s, notify = M.step(s, { pid = 5, frontmost_pid = 9 })
    eq(notify, false, "tick " .. i .. " does not notify")
end
eq(s.ticks, 3, "ticks after 3 ticks")
s, notify = M.step(s, { pid = 5, frontmost_pid = 9 })
eq(notify, true, "tick 4 notifies")
eq(s.ticks, 4, "ticks after 4 ticks")
s, notify = M.step(s, { pid = 5, frontmost_pid = 9 })
eq(notify, false, "tick 5 does not repeat notify")

-- step: releasing resets; re-holding notifies again
s, notify = M.step(s, { pid = nil, frontmost_pid = 9 })
eq(notify, false, "release does not notify")
eq(s.pid, nil, "release clears pid")
eq(s.ticks, 0, "release clears ticks")
eq(s.notified, false, "release clears notified")
for i = 1, 3 do
    s, notify = M.step(s, { pid = 5, frontmost_pid = 9 })
    eq(notify, false, "re-hold tick " .. i .. " does not notify")
end
s, notify = M.step(s, { pid = 5, frontmost_pid = 9 })
eq(notify, true, "re-hold tick 4 notifies again")

-- step: holder changes between ticks
s = M.new_state()
s, notify = M.step(s, { pid = 5, frontmost_pid = 9 })
s, notify = M.step(s, { pid = 5, frontmost_pid = 9 })
s, notify = M.step(s, { pid = 6, frontmost_pid = 9 })
eq(notify, false, "holder change does not notify")
eq(s.ticks, 1, "new holder starts at 1 tick")
eq(s.pid, 6, "new holder pid")
for i = 1, 3 do
    s, notify = M.step(s, { pid = 6, frontmost_pid = 9 })
end
eq(notify, true, "new holder notifies after 4 ticks")

-- step: holder frontmost for a while, then goes to background
s = M.new_state()
for i = 1, 10 do
    s, notify = M.step(s, { pid = 9, frontmost_pid = 9 })
    eq(notify, false, "frontmost tick " .. i .. " does not notify")
    eq(s.ticks, 0, "frontmost tick " .. i .. " keeps ticks at 0")
end
s, notify = M.step(s, { pid = 9, frontmost_pid = 2 })
eq(s.ticks, 1, "first background tick starts streak at 1")

-- step: does not mutate its input
local input = { pid = 5, ticks = 3, notified = false }
M.step(input, { pid = 5, frontmost_pid = 9 })
eq(input.pid, 5, "step leaves input pid")
eq(input.ticks, 3, "step leaves input ticks")
eq(input.notified, false, "step leaves input notified")

-- Shell-level cases: tick/start/stop with stubbed deps.
local function stub(overrides)
    local deps = {
        secure_enabled = function() return true end,
        ioreg = function() return '"kCGSSessionSecureInputPID"=5' end,
        frontmost_pid = function() return 9 end,
        app_name = function() return "Dia" end,
        notify = function() end,
    }
    for k, v in pairs(overrides) do
        deps[k] = v
    end
    return deps
end

M.stop()
local ioreg_calls, notify_calls = 0, {}
local deps = stub({
    secure_enabled = function() return false end,
    ioreg = function() ioreg_calls = ioreg_calls + 1 return "" end,
    notify = function(msg) table.insert(notify_calls, msg) end,
})
for _ = 1, 10 do M.tick(deps) end
eq(#notify_calls, 0, "secure input off never notifies")
eq(ioreg_calls, 0, "secure input off never reads ioreg")

M.stop()
notify_calls = {}
deps = stub({ notify = function(msg) table.insert(notify_calls, msg) end })
for _ = 1, 3 do M.tick(deps) end
eq(#notify_calls, 0, "no notify before threshold")
M.tick(deps)
eq(#notify_calls, 1, "notifies once at threshold")
eq(notify_calls[1], M.message("Dia", 120), "notification message names app and duration")
M.tick(deps)
M.tick(deps)
eq(#notify_calls, 1, "does not repeat within the same episode")

M.stop()
notify_calls = {}
deps = stub({
    app_name = function() return nil end,
    notify = function(msg) table.insert(notify_calls, msg) end,
})
for _ = 1, 4 do M.tick(deps) end
eq(#notify_calls, 1, "unresolved holder still notifies")
assert(string.find(notify_calls[1], "PID 5", 1, true), "unresolved holder falls back to PID")

M.stop()
notify_calls = {}
deps = stub({
    ioreg = function() return "no holder key here" end,
    notify = function(msg) table.insert(notify_calls, msg) end,
})
for _ = 1, 10 do M.tick(deps) end
eq(#notify_calls, 0, "unreadable PID never notifies")

M.stop()
local first = M.start()
local second = M.start()
eq(first:running(), false, "first timer stopped by second start")
eq(second:running(), true, "second timer running")
M.stop()
eq(second:running(), false, "stop stops the timer")

return "ok"
