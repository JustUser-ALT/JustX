-- ResizeDragCallProbe.lua
-- Captures the next native ResizeParameters:Drag call and forwards it unchanged.
-- Run this, then perform one normal resize drag on a single block.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local BuildModeGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local BMC = require(RS.BuildMode.BuildModeClient)
local class = debug.getupvalues(BMC.new)[3]

local function log(...)
    print("[ResizeDragCallProbe]", ...)
end

local ClientState
for _ = 1, 100 do
    for _, object in ipairs(getgc(true)) do
        if type(object) == "table"
            and getmetatable(object) == class
            and rawget(object, "ScreenGui") == BuildModeGui
            and rawget(object, "ResizeHandles") then
            ClientState = object
            break
        end
    end
    if ClientState then break end
    task.wait(0.1)
end

if not ClientState then
    warn("[ResizeDragCallProbe] ClientState not found")
    return
end

local ok, connections = pcall(getconnections, ClientState.ResizeHandles.MouseButton1Down)
if not ok or not connections then
    warn("[ResizeDragCallProbe] Cannot read MouseButton1Down connections")
    return
end

local moduleTable
for _, connection in ipairs(connections) do
    local fn = connection.Function
    if type(fn) == "function" then
        for _, value in pairs(debug.getupvalues(fn)) do
            if type(value) == "table"
                and type(rawget(value, "new")) == "function"
                and type(rawget(value, "Drag")) == "function"
                and type(rawget(value, "Reset")) == "function"
                and type(rawget(value, "__index")) == "table" then
                moduleTable = value
                break
            end
        end
    end
    if moduleTable then break end
end

if not moduleTable then
    warn("[ResizeDragCallProbe] ResizeParameters module not found")
    return
end

local indexTable = moduleTable.__index
local original = indexTable.Drag
if type(original) ~= "function" then
    warn("[ResizeDragCallProbe] __index.Drag not found")
    return
end

local captured = false

local function describe(value)
    local kind = typeof(value)
    if kind == "Instance" then
        return value:GetFullName() .. " [" .. value.ClassName .. "]"
    end
    if kind == "CFrame" or kind == "Vector3" then
        return tostring(value)
    end
    return tostring(value) .. " [" .. kind .. "]"
end

local function inspect(label, value, depth)
    depth = depth or 0
    if type(value) ~= "table" then
        log(string.rep("  ", depth) .. label, describe(value))
        return
    end

    log(string.rep("  ", depth) .. label, "table")
    if depth >= 3 then
        log(string.rep("  ", depth + 1) .. "... depth limit")
        return
    end

    local count = 0
    for key, item in pairs(value) do
        count += 1
        if count > 30 then
            log(string.rep("  ", depth + 1) .. "... truncated")
            break
        end
        inspect("[" .. tostring(key) .. "]", item, depth + 1)
    end
end

indexTable.Drag = function(self, ...)
    if captured then
        return original(self, ...)
    end
    captured = true

    local args = table.pack(...)
    log("===== DRAG CALL =====")
    log("argument count:", args.n)
    inspect("self", self, 0)
    for index = 1, args.n do
        inspect("arg[" .. index .. "]", args[index], 0)
    end

    local results = table.pack(original(self, table.unpack(args, 1, args.n)))
    indexTable.Drag = original
    log("Drag restored; native resize continues unchanged")
    log("return count:", results.n)
    for index = 1, results.n do
        inspect("return[" .. index .. "]", results[index], 0)
    end
    log("===== END =====")
    return table.unpack(results, 1, results.n)
end

log("Armed. Now perform one normal resize drag on a single block.")
