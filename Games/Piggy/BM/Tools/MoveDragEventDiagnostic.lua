--==================================================
-- MOVE DRAG EVENT DIAGNOSTIC
-- Observe-only: records native MouseDrag arguments and
-- selected model pivot changes while the user drags.
-- Does not move blocks or replace native callbacks.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PREFIX = "[MoveDragEvent]"
local function log(...)
    print(PREFIX, ...)
end

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local BuildModeClient = require(RS:WaitForChild("BuildMode"):WaitForChild("BuildModeClient"))

local function findHandles()
    local upvalues = debug.getupvalues(BuildModeClient.new)
    local class = upvalues and upvalues[3]
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

log("MoveHandles:", handles.ClassName, handles:GetFullName())
log("ClientState SelectedBlock:", tostring(clientState.SelectedBlock))

local function describe(value)
    local kind = typeof(value)
    if kind == "EnumItem" then
        return tostring(value)
    elseif kind == "Instance" then
        return value:GetFullName()
    elseif kind == "Vector3" then
        return string.format("(%.4f, %.4f, %.4f)", value.X, value.Y, value.Z)
    elseif kind == "CFrame" then
        local p = value.Position
        return string.format("CFrame(%.4f, %.4f, %.4f)", p.X, p.Y, p.Z)
    end
    return tostring(value) .. " [" .. kind .. "]"
end

for _, property in ipairs({"Adornee", "Visible", "Style", "Faces", "Parent"}) do
    local ok, value = pcall(function() return handles[property] end)
    if ok then
        log("PROPERTY", property, describe(value))
    end
end

local sampleCount = 0
local maxSamples = 24
local lastSignature
local dragActive = false
local lastPivot
local lastBlock
local connections = {}

local function getSelected()
    local block = clientState.SelectedBlock
    if typeof(block) == "Instance" and block:IsA("Model") then
        local ok, pivot = pcall(function() return block:GetPivot() end)
        if ok then return block, pivot end
    end
end

connections[#connections + 1] = handles.MouseButton1Down:Connect(function(...)
    dragActive = true
    lastBlock, lastPivot = getSelected()
    log("DRAG START", "block=", tostring(lastBlock), "pivot=", lastPivot and describe(lastPivot) or "nil")
end)

connections[#connections + 1] = handles.MouseDrag:Connect(function(...)
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
        local delta = pivot.Position - lastPivot.Position
        deltaText = describe(delta)
    end

    local signature = table.concat(parts, " | ") .. " | pivot=" .. (pivot and describe(pivot) or "nil") .. " | delta=" .. deltaText
    if signature ~= lastSignature then
        log("MOUSEDRAG", sampleCount, signature)
        lastSignature = signature
    end

    lastBlock, lastPivot = block, pivot
end)

connections[#connections + 1] = handles.MouseButton1Up:Connect(function(...)
    local args = table.pack(...)
    local parts = {}
    for index = 1, args.n do
        parts[#parts + 1] = "arg" .. index .. "=" .. describe(args[index])
    end
    local block, pivot = getSelected()
    log("DRAG END", table.concat(parts, " | "), "block=", tostring(block), "pivot=", pivot and describe(pivot) or "nil")
    dragActive = false
    lastBlock, lastPivot = nil, nil
end)

log("Ready. Select one block, then drag one Move handle a short distance.")
log("Only the first", maxSamples, "MouseDrag samples will be logged.")
log("No block or native handler is modified.")
