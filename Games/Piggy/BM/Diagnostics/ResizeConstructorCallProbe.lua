-- ResizeConstructorCallProbe.lua
-- Captures the next native ResizeParameters.new call without changing its arguments or return values.
-- Run this, then perform one normal resize drag on a single block.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local BuildModeGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local BMC = require(RS.BuildMode.BuildModeClient)
local class = debug.getupvalues(BMC.new)[3]

local function log(...)
    print("[ResizeConstructorCallProbe]", ...)
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
    warn("[ResizeConstructorCallProbe] ClientState not found")
    return
end

local ok, connections = pcall(getconnections, ClientState.ResizeHandles.MouseButton1Down)
if not ok or not connections then
    warn("[ResizeConstructorCallProbe] Cannot read MouseButton1Down connections")
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
                and type(rawget(value, "Reset")) == "function" then
                moduleTable = value
                break
            end
        end
    end
    if moduleTable then break end
end

if not moduleTable then
    warn("[ResizeConstructorCallProbe] ResizeParameters module not found")
    return
end

local original = moduleTable.new
local captured = false

local function describe(value)
    local kind = typeof(value)
    if kind == "Instance" then
        return value:GetFullName() .. " [" .. value.ClassName .. "]"
    end
    if kind == "CFrame" then
        return tostring(value)
    end
    if kind == "Vector3" then
        return tostring(value)
    end
    return tostring(value) .. " [" .. kind .. "]"
end

local function inspectTable(label, value)
    if type(value) ~= "table" then
        log(label, describe(value))
        return
    end

    local count = 0
    for key, item in pairs(value) do
        count += 1
        if count > 20 then
            log(label, "... truncated")
            break
        end
        if type(item) == "table" then
            log(label .. "." .. tostring(key), "table")
            local nested = 0
            for nestedKey, nestedValue in pairs(item) do
                nested += 1
                if nested > 12 then
                    log("  ... nested truncated")
                    break
                end
                log("  [" .. tostring(nestedKey) .. "]", describe(nestedValue))
            end
        else
            log(label .. "." .. tostring(key), describe(item))
        end
    end
end

moduleTable.new = function(...)
    if captured then
        return original(...)
    end
    captured = true

    local args = table.pack(...)
    log("===== CONSTRUCTOR CALL =====")
    log("argument count:", args.n)
    for index = 1, args.n do
        inspectTable("arg[" .. index .. "]", args[index])
    end

    local results = table.pack(original(...))
    log("return count:", results.n)
    for index = 1, results.n do
        inspectTable("return[" .. index .. "]", results[index])
    end

    moduleTable.new = original
    log("Constructor restored; native resize continues unchanged")
    log("===== END =====")
    return table.unpack(results, 1, results.n)
end

log("Armed. Now perform one normal resize drag on a single block.")
