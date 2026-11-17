-- Native Move Selection Diagnostic v7 (read-only)
-- Run in ORIGINAL Piggy Build Mode with a block selected and Move active.

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local modes = RS:WaitForChild("BuildMode"):WaitForChild("Modes")

local count, LIMIT = 0, 110
local function log(v)
    if count >= LIMIT then return end
    count += 1
    print("[MoveState] " .. tostring(v))
end

local function describe(v)
    local t = typeof(v)
    if t == "Instance" then
        local ok, name = pcall(function() return v:GetFullName() end)
        return (ok and name or v.Name) .. " <" .. v.ClassName .. ">"
    end
    if type(v) == "table" then return "table" .. (getmetatable(v) and " [mt]" or "") end
    return tostring(v) .. " <" .. t .. ">"
end

local function inspectFunction(label, fn)
    log(label .. "=" .. describe(fn))
    if type(fn) ~= "function" or not debug then return end
    if type(debug.getconstants) == "function" then
        local ok, values = pcall(debug.getconstants, fn)
        if ok and type(values) == "table" then
            for i, value in pairs(values) do
                if type(value) == "string" then log("  C" .. tostring(i) .. "=" .. value) end
            end
        end
    end
    if type(debug.getupvalues) == "function" then
        local ok, values = pcall(debug.getupvalues, fn)
        if ok and type(values) == "table" then
            for i, value in pairs(values) do log("  U" .. tostring(i) .. "=" .. describe(value)) end
        end
    end
end

log("===== MOVE ACTION SOURCE V7 =====")
log("GUI=" .. gui:GetFullName())
for _, name in ipairs({"Move", "Select"}) do
    local module = modes:FindFirstChild(name)
    if not module then log(name .. " missing"); continue end
    if type(decompile) == "function" then
        local ok, source = pcall(decompile, module)
        if ok and type(source) == "string" then
            log("----- " .. name .. " FULL SOURCE -----")
            local lines = string.split(source, "\n")
            for i, line in ipairs(lines) do
                if #line > 240 then line = string.sub(line, 1, 240) .. "..." end
                log(name .. ":" .. i .. ": " .. line)
            end
        else
            log(name .. " decompile failed: " .. tostring(source))
        end
    else
        log("decompile unavailable")
    end
    local okReq, result = pcall(require, module)
    if okReq and type(result) == "table" then
        log("----- " .. name .. " EXPORTS -----")
        for key, value in pairs(result) do
            if type(value) == "function" then inspectFunction(name .. "." .. tostring(key), value)
            else log(name .. "." .. tostring(key) .. "=" .. describe(value)) end
        end
    else
        log(name .. " require failed or non-table: " .. tostring(result))
    end
end
log("===== END =====")
