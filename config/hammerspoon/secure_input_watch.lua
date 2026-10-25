local M = {}

M.TICK_SECONDS = 30
M.THRESHOLD_TICKS = 4

function M.parse_holder_pid(ioreg_output)
    local pid = string.match(ioreg_output, '"kCGSSessionSecureInputPID"=(%d+)')
    if pid == nil then
        return nil
    end
    return tonumber(pid)
end

function M.new_state()
    return { pid = nil, ticks = 0, notified = false }
end

function M.step(state, sample)
    if sample.pid == nil or sample.pid == sample.frontmost_pid then
        return M.new_state(), false
    end

    local next_state
    if sample.pid == state.pid then
        next_state = { pid = state.pid, ticks = state.ticks + 1, notified = state.notified }
    else
        next_state = { pid = sample.pid, ticks = 1, notified = false }
    end

    local notify = next_state.ticks >= M.THRESHOLD_TICKS and not next_state.notified
    if notify then
        next_state.notified = true
    end
    return next_state, notify
end

function M.message(app_name, seconds)
    return string.format(
        "%s has held Secure Input for %ds. Option hotkeys (Raycast) are blocked. Restart %s.",
        app_name, seconds, app_name)
end

local state = M.new_state()
local timer

local function default_deps()
    return {
        secure_enabled = function() return hs.eventtap.isSecureInputEnabled() end,
        ioreg = function() return hs.execute("/usr/sbin/ioreg -l -w0") end,
        frontmost_pid = function()
            local app = hs.application.frontmostApplication()
            return app and app:pid()
        end,
        app_name = function(pid)
            local app = hs.application.applicationForPID(pid)
            return app and app:name()
        end,
        notify = function(msg)
            hs.notify.new({ title = "Secure Input held", informativeText = msg, withdrawAfter = 0 }):send()
        end,
    }
end

function M.tick(overrides)
    local deps = default_deps()
    for k, v in pairs(overrides or {}) do
        deps[k] = v
    end

    local sample = { pid = nil, frontmost_pid = deps.frontmost_pid() }
    if deps.secure_enabled() then
        sample.pid = M.parse_holder_pid(deps.ioreg())
    end

    local notify
    state, notify = M.step(state, sample)
    if notify then
        local name = deps.app_name(sample.pid) or ("PID " .. sample.pid)
        deps.notify(M.message(name, M.THRESHOLD_TICKS * M.TICK_SECONDS))
    end
end

function M.start()
    M.stop()
    timer = hs.timer.doEvery(M.TICK_SECONDS, function() M.tick() end)
    return timer
end

function M.stop()
    if timer then
        timer:stop()
        timer = nil
    end
    state = M.new_state()
end

return M
