--==================================================
-- RESIZE GROUP PROBE
-- Read-only runtime diagnostics for the native Piggy Resize tool.
-- Does not modify handles, callbacks, blocks, or remotes.
--==================================================

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")
local BMC = require(RS:WaitForChild("BuildMode"):WaitForChild("BuildModeClient"))

local function safeToString(value)
    local ok, result = pcall(tostring, value)
    return ok and result or "<tostring failed>"
end

local function printValue(label, value)
    print("[ResizeProbe] " .. label .. " = " .. safeToString(value))
end

local class
do
    local ok, upvalues = pcall(debug.getupvalues, BMC.new)
    if ok and type(upvalues) == "table" then
        class = upvalues[3]
    end
end

assert(class, "[ResizeProbe] BuildModeClient class not found")

local ClientState
for attempt = 1, 100 do
    for _, object in ipairs(getgc(true)) do
        if type(object) == "table"
            and getmetatable(object) == class
            and rawget(object, "ScreenGui") == BuildModeGui then
            ClientState = object
            break
        end
    end
    if ClientState then break end
    task.wait(0.1)
end

assert(ClientState, "[ResizeProbe] ClientState not found")

local Handles = ClientState.ResizeHandles
assert(Handles, "[ResizeProbe] ClientState.ResizeHandles not found")

print("========== RESIZE GROUP PROBE ==========")
printValue("ClientState.SelectedBlock", ClientState.SelectedBlock)
printValue("ResizeHandles class", getmetatable(Handles))
printValue("ResizeHandles._Adornee", rawget(Handles, "_Adornee"))

for _, signalName in ipairs({"MouseButton1Down", "MouseDrag", "MouseButton1Up"}) do
    local signal = Handles[signalName]
    printValue("Signal " .. signalName, signal)

    if signal and type(getconnections) == "function" then
        local ok, connections = pcall(getconnections, signal)
        if ok and type(connections) == "table" then
            for connectionIndex, connection in ipairs(connections) do
                local fn = connection.Function
                print("[ResizeProbe] " .. signalName .. " connection #" .. connectionIndex
                    .. " Enabled=" .. safeToString(connection.Enabled)
                    .. " Function=" .. safeToString(fn))

                if type(fn) == "function" then
                    local constantsOk, constants = pcall(debug.getconstants, fn)
                    if constantsOk and type(constants) == "table" then
                        for index, value in pairs(constants) do
                            print("[ResizeProbe]   constant[" .. index .. "] = " .. safeToString(value))
                        end
                    end

                    local upvaluesOk, upvalues = pcall(debug.getupvalues, fn)
                    if upvaluesOk and type(upvalues) == "table" then
                        for index, value in pairs(upvalues) do
                            local description = safeToString(value)
                            if type(value) == "table" then
                                local keys = {}
                                for key in pairs(value) do
                                    table.insert(keys, safeToString(key))
                                    if #keys >= 12 then break end
                                end
                                description = "table keys={" .. table.concat(keys, ", ") .. "}"
                            elseif typeof(value) == "Instance" then
                                description = value:GetFullName() .. " [" .. value.ClassName .. "]"
                            end
                            print("[ResizeProbe]   upvalue[" .. index .. "] (" .. type(value) .. ") = " .. description)
                        end
                    end
                end
            end
        else
            print("[ResizeProbe] getconnections failed for " .. signalName .. ": " .. safeToString(connections))
        end
    end
end

local Functions = RS:FindFirstChild("Functions")
if Functions then
    print("[ResizeProbe] ReplicatedStorage.Functions:")
    for _, child in ipairs(Functions:GetChildren()) do
        print("[ResizeProbe]   " .. child.Name .. " [" .. child.ClassName .. "]")
    end
else
    print("[ResizeProbe] ReplicatedStorage.Functions not found")
end

local Events = RS:FindFirstChild("Events")
if Events then
    print("[ResizeProbe] ReplicatedStorage.Events candidates:")
    for _, child in ipairs(Events:GetChildren()) do
        local name = child.Name:lower()
        if name:find("resize") or name:find("move") or name:find("block") or name:find("build") then
            print("[ResizeProbe]   " .. child.Name .. " [" .. child.ClassName .. "]")
        end
    end
end

local selected = ClientState.SelectedBlock
if selected and selected:IsA("Model") then
    print("[ResizeProbe] Selected model: " .. selected:GetFullName())
    printValue("Selected model pivot", selected:GetPivot())
    local ok, boxCFrame, boxSize = pcall(function()
        return selected:GetBoundingBox()
    end)
    if ok then
        printValue("Selected model bounding box", boxCFrame)
        printValue("Selected model bounding size", boxSize)
    end
    for _, descendant in ipairs(selected:GetDescendants()) do
        if descendant:IsA("BasePart") then
            print("[ResizeProbe]   Part " .. descendant:GetFullName()
                .. " Size=" .. safeToString(descendant.Size)
                .. " CFrame=" .. safeToString(descendant.CFrame))
        end
    end
else
    print("[ResizeProbe] No selected model at probe time; run while one block is selected")
end

print("========== END RESIZE GROUP PROBE ==========")
