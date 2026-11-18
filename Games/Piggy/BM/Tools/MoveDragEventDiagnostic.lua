--==================================================
-- MOVE DRAG EVENT DIAGNOSTIC
-- Observe-only: records native MouseDrag arguments and
-- selected model pivot changes while the user drags.
-- Does not move blocks or replace native callbacks.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local PREFIX = "[MoveDragEvent]"
local function log(...)
    print(PREFIX, ...)
end

local player = Players.LocalPlayer
player:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local BuildModeClient = require(RS:WaitForChild("BuildMode"):WaitForChild("BuildModeClient"))

local function findHandles()
    local ok, upvalues = pcall(debug.getupvalues, BuildModeClient.new)
    local class = ok and upvalues and upvalues[3]
    if not class then return nil end

    for _, object in ipairs(getgc(true)) do
        if type(object) == "table" and getmetatable(object) == class then
            local handles = rawget(object, "MoveHandles")
            if handles then
                return handles, object
            end
        end
    end
end

local handles, clientState = findHandles()
if not handles then
    log("Could not locate live MoveHandles")
    return
end

log("MoveHandles type:", typeof(handles), "Lua type:", type(handles))
log("ClientState SelectedBlock:", tostring(clientState.SelectedBlock))

local function describe(value)
    local kind = typeof(value)
    if kind == "EnumItem" then
        return tostring(value)
    elseif kind == "Instance" then
        local ok, fullName = pcall(function() return value:GetFullName() end)
        return ok and fullName or tostring(value)
    elseif kind == "Vector3" then
        return string.format("(%.4f, %.4f, %.4f)", value.X, value.Y, value.Z)
    elseif kind == "CFrame" then
        local p = value.Position
        return string.format("CFrame(%.4f, %.4f, %.4f)", p.X, p.Y, p.Z)
    elseif kind == "RBXScriptSignal" then
        return "RBXScriptSignal"
    end
    return tostring(value) .. " [" .. kind .. "]"
end

if type(handles) == "table" then
    local keyCount = 0
    for key, value in pairs(handles) do
        keyCount = keyCount + 1
        log("HANDLE KEY", tostring(key), typeof(value), describe(value))
        if keyCount >= 60 then
            log("Handle keys truncated at 60")
            break
        end
    end
end

local function getSelected()
    local block = clientState.SelectedBlock
    if typeof(block) == "Instance" and block:IsA("Model") then
        local ok, pivot = pcall(function() return block:GetPivot() end)
        if ok then return block, pivot end
    end
end

local sampleCount = 0
local maxSamples = 24
local lastSignature
local lastPivot
local connections = {}

local function connectSignal(signalName, callback)
    local ok, signal = pcall(function()
        return handles[signalName]
    end)

    if not ok or typeof(signal) ~= "RBXScriptSignal" then
        log("Signal unavailable:", signalName, "value=", ok and describe(signal) or tostring(signal))
        return
    end

    local connected, connection = pcall(function()
        return signal:Connect(callback)
    end)

    if connected then
        connections[#connections + 1] = connection
        log("Observing", signalName)
    else
        log("Could not connect", signalName, tostring(connection))
    end
end

connectSignal("MouseButton1Down", function(...)
    local block, pivot = getSelected()
    lastPivot = pivot
    log("DRAG START", "block=", block and block:GetFullName() or "nil",
        "pivot=", pivot and describe(pivot) or "nil")
end)

connectSignal("MouseDrag", function(...)
    if sampleCount >= maxSamples then return end
    sampleCount = sampleCount + 1

    local args = table.pack(...)
    local parts = {}
    for index = 1, args.n do
        parts[#parts + 1] = "arg" .. index .. "=" .. describe(args[index])
    end

    local block, pivot = getSelected()
    local deltaText = "n/a"
    if lastPivot and pivot then
        deltaText = describe(pivot.Position - lastPivot.Position)
    end

    local signature = table.concat(parts, " | ") ..
        " | pivot=" .. (pivot and describe(pivot) or "nil") ..
        " | delta=" .. deltaText

    if signature ~= lastSignature then
        log("MOUSEDRAG", sampleCount, signature)
        lastSignature = signature
    end

    lastPivot = pivot
end)

connectSignal("MouseButton1Up", function(...)
    local args = table.pack(...)
    local parts = {}
    for index = 1, args.n do
        parts[#parts + 1] = "arg" .. index .. "=" .. describe(args[index])
    end

    local block, pivot = getSelected()
    log("DRAG END", table.concat(parts, " | "),
        "block=", block and block:GetFullName() or "nil",
        "pivot=", pivot and describe(pivot) or "nil")
    lastPivot = nil
end)

log("Ready. Select one block, then drag one Move handle a short distance.")
log("Only the first", maxSamples, "MouseDrag samples will be logged.")
log("No block or native handler is modified.")
