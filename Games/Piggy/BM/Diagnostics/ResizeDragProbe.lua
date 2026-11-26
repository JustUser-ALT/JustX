-- ResizeDragProbe.lua
-- Compact read-only probe for the native ResizeParameters/Drag module.
-- Run with one block selected in native Resize mode.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local BuildModeGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local BMC = require(RS.BuildMode.BuildModeClient)
local class = debug.getupvalues(BMC.new)[3]

local function log(...)
    print("[ResizeDragProbe]", ...)
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
    warn("[ResizeDragProbe] ClientState not found")
    return
end

local signal = ClientState.ResizeHandles.MouseButton1Down
local ok, connections = pcall(getconnections, signal)
if not ok or not connections then
    warn("[ResizeDragProbe] Cannot read MouseButton1Down connections")
    return
end

local moduleTable
for _, connection in ipairs(connections) do
    local fn = connection.Function
    if type(fn) == "function" then
        local ups = debug.getupvalues(fn)
        for index, value in pairs(ups) do
            if type(value) == "table"
                and (type(rawget(value, "Drag")) == "function"
                    or type(rawget(value, "new")) == "function")
                and type(rawget(value, "Reset")) == "function" then
                moduleTable = value
                log("Found module table in callback upvalue", index)
                break
            end
        end
    end
    if moduleTable then break end
end

if not moduleTable then
    warn("[ResizeDragProbe] ResizeParameters module table not found")
    return
end

local keys = {}
for key, value in pairs(moduleTable) do
    table.insert(keys, tostring(key) .. ":" .. typeof(value))
end
table.sort(keys)
log("Module keys:", table.concat(keys, " | "))

for _, name in ipairs({"new", "Drag", "Reset"}) do
    local fn = rawget(moduleTable, name)
    if type(fn) == "function" then
        log("FUNCTION", name)
        local constants = debug.getconstants(fn)
        local count = 0
        for index, value in pairs(constants) do
            count += 1
            if count <= 35 then
                log(" C" .. index, tostring(value))
            end
        end
        if count > 35 then log(" constants truncated:", count) end

        local ups = debug.getupvalues(fn)
        for index, value in pairs(ups) do
            if type(value) == "table" then
                local upKeys = {}
                for key in pairs(value) do
                    table.insert(upKeys, tostring(key))
                    if #upKeys >= 12 then break end
                end
                table.sort(upKeys)
                log(" U" .. index, "table keys={" .. table.concat(upKeys, ",") .. "}")
            else
                log(" U" .. index, typeof(value), tostring(value))
            end
        end
    end
end

log("===== END =====")
