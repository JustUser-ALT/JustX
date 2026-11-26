-- ResizeConstructorProbe.lua
-- Compact read-only inspection of ResizeParameters constructor and __index.
-- Run with one block selected in native Resize mode.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local BuildModeGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local BMC = require(RS.BuildMode.BuildModeClient)
local class = debug.getupvalues(BMC.new)[3]

local function log(...)
    print("[ResizeConstructorProbe]", ...)
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
    warn("[ResizeConstructorProbe] ClientState not found")
    return
end

local connectionsOk, connections = pcall(getconnections, ClientState.ResizeHandles.MouseButton1Down)
if not connectionsOk or not connections then
    warn("[ResizeConstructorProbe] Cannot read MouseButton1Down")
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
    warn("[ResizeConstructorProbe] Module not found")
    return
end

local function inspectFunction(label, fn)
    if type(fn) ~= "function" then return end
    log("FUNCTION", label)
    local ok, info = pcall(debug.getinfo, fn)
    if ok and info then
        log(" signature params=", info.nparams, "vararg=", info.isvararg, "what=", info.what)
    else
        log(" signature unavailable")
    end

    local constantsOk, constants = pcall(debug.getconstants, fn)
    if constantsOk and constants then
        for index, value in pairs(constants) do
            if index <= 30 then
                log(" C" .. index, tostring(value))
            end
        end
    end

    local upsOk, ups = pcall(debug.getupvalues, fn)
    if upsOk and ups then
        for index, value in pairs(ups) do
            if type(value) == "table" then
                local keys = {}
                for key in pairs(value) do
                    table.insert(keys, tostring(key))
                    if #keys >= 15 then break end
                end
                table.sort(keys)
                log(" U" .. index, "table keys={" .. table.concat(keys, ",") .. "}")
            else
                log(" U" .. index, typeof(value), tostring(value))
            end
        end
    end
end

inspectFunction("new", moduleTable.new)
inspectFunction("Drag", moduleTable.Drag)
inspectFunction("Reset", moduleTable.Reset)

local indexTable = moduleTable.__index
if type(indexTable) == "table" then
    local names = {}
    for key, value in pairs(indexTable) do
        table.insert(names, tostring(key) .. ":" .. typeof(value))
    end
    table.sort(names)
    log("__index members:", table.concat(names, " | "))

    for _, name in ipairs({"Drag", "Reset"}) do
        inspectFunction("__index." .. name, indexTable[name])
    end
else
    log("__index type:", typeof(indexTable))
end

log("===== END =====")
