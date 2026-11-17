-- Native Move Selection Diagnostic v6 (read-only)
-- Run in ORIGINAL Piggy Build Mode with a block selected and Move active.

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local modes = RS:WaitForChild("BuildMode"):WaitForChild("Modes")

local count, LIMIT = 0, 100
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
    return tostring(v) .. " <" .. t .. ">"
end

local function inspectModule(name)
    local module = modes:FindFirstChild(name)
    if not module then log(name .. ": module missing"); return end
    log("===== MODULE " .. name .. " =====")
    log("Instance=" .. describe(module))
    if type(decompile) ~= "function" then
        log("decompile unavailable")
        return
    end
    local ok, source = pcall(decompile, module)
    if not ok or type(source) ~= "string" then
        log("decompile failed: " .. tostring(source))
        return
    end
    log("SourceLength=" .. #source)
    local lines = string.split(source, "\n")
    local hits, shown = {}, 0
    for i, line in ipairs(lines) do
        local lower = string.lower(line)
        if string.find(lower, "selectedblock", 1, true)
            or string.find(lower, "setadornee", 1, true)
            or string.find(lower, "movehandles", 1, true)
            or string.find(lower, "boxselection", 1, true)
            or string.find(lower, "action", 1, true)
            or string.find(lower, "selection", 1, true)
            or string.find(lower, "adornee", 1, true) then
            hits[#hits + 1] = i
        end
    end
    log("RelevantLines=" .. #hits)
    for _, lineNo in ipairs(hits) do
        if shown >= 32 then break end
        shown += 1
        local line = lines[lineNo] or ""
        if #line > 220 then line = string.sub(line, 1, 220) .. "..." end
        log(name .. ":" .. lineNo .. ": " .. line)
    end
    if #hits == 0 then
        for i = 1, math.min(#lines, 12) do
            local line = lines[i]
            if #line > 220 then line = string.sub(line, 1, 220) .. "..." end
            log(name .. ":" .. i .. ": " .. line)
        end
    end
end

log("===== MODE MODULE DIAGNOSTIC V6 =====")
log("GUI=" .. gui:GetFullName())
inspectModule("Move")
inspectModule("Select")
log("===== END =====")
