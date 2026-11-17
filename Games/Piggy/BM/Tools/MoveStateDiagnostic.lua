-- Native Move Tool State Diagnostic (compact)
-- Read-only. Run in the ORIGINAL Piggy Build Mode while Move is active.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local BMC = require(RS:WaitForChild("BuildMode"):WaitForChild("BuildModeClient"))

local lines = 0
local LIMIT = 58
local function log(message)
    if lines >= LIMIT then return end
    lines = lines + 1
    print("[MoveState] " .. tostring(message))
end

local function describe(value)
    local kind = typeof(value)
    if kind == "Instance" then
        local ok, name = pcall(function() return value:GetFullName() end)
        return (ok and name or value.Name) .. " <" .. value.ClassName .. ">"
    elseif kind == "table" then
        return "table" .. (getmetatable(value) and " [metatable]" or "")
    elseif kind == "function" then
        return "function"
    end
    return tostring(value) .. " <" .. kind .. ">"
end

local function listKeys(label, value, max)
    if type(value) ~= "table" then
        log(label .. " = " .. describe(value))
        return
    end
    log(label .. " keys:")
    local count = 0
    for key, item in pairs(value) do
        count = count + 1
        if count > max then
            log("  ... truncated")
            break
        end
        log("  " .. tostring(key) .. " : " .. typeof(item))
    end
    if count == 0 then log("  <empty>") end
end

local function listMethods(label, value)
    if type(value) ~= "table" then return end
    local mt = getmetatable(value)
    local index = type(mt) == "table" and rawget(mt, "__index")
    log(label .. " metatable.__index = " .. describe(index))
    local source = type(index) == "table" and index or (type(mt) == "table" and mt)
    if type(source) ~= "table" then return end
    local count = 0
    for key, item in pairs(source) do
        if type(item) == "function" then
            count = count + 1
            if count <= 16 then log("  method: " .. tostring(key)) end
        end
    end
    log(label .. " method count = " .. count)
end

log("========== COMPACT NATIVE MOVE DIAGNOSTIC ==========")
log("BuildModeGui = " .. gui:GetFullName())

if type(getgc) ~= "function" or not debug or type(debug.getupvalues) ~= "function" then
    log("Required executor functions unavailable (getgc/debug.getupvalues).")
    return
end

local ok, ups = pcall(debug.getupvalues, BMC.new)
local class = ok and type(ups) == "table" and ups[3]
if not class then
    log("Could not resolve ClientState class from BMC.new upvalue 3.")
    return
end
log("ClientState class = " .. describe(class))

local okGc, gc = pcall(getgc, true)
if not okGc or type(gc) ~= "table" then
    log("getgc(true) failed.")
    return
end

local states = {}
for _, obj in ipairs(gc) do
    if type(obj) == "table" then
        local okMt, mt = pcall(getmetatable, obj)
        if okMt and mt == class then
            states[#states + 1] = obj
        end
    end
end
log("ClientState instances found = " .. #states)

for i, state in ipairs(states) do
    if i > 2 then break end
    log("---- ClientState #" .. i .. " ----")
    log("SelectedBlock = " .. describe(rawget(state, "SelectedBlock")))
    log("MoveHandles = " .. describe(rawget(state, "MoveHandles")))
    local toolbar = rawget(state, "Toolbar")
    log("Toolbar = " .. describe(toolbar))

    local handles = rawget(state, "MoveHandles")
    if type(handles) == "table" then
        log("MoveHandles._Adornee = " .. describe(rawget(handles, "_Adornee")))
        listMethods("MoveHandles", handles)
    end

    if type(toolbar) == "table" then
        local direct = rawget(toolbar, "BuildModeClient")
        local buildingToolbar = rawget(toolbar, "BuildingModeToolbar")
        local nested = type(buildingToolbar) == "table" and rawget(buildingToolbar, "BuildModeClient") or nil
        log("Toolbar.BuildModeClient = " .. describe(direct))
        log("Toolbar.BuildingModeToolbar = " .. describe(buildingToolbar))
        log("BuildingModeToolbar.BuildModeClient = " .. describe(nested))
        listKeys("Toolbar.BuildModeClient", direct, 12)
        listMethods("Toolbar.BuildModeClient", direct)
        listKeys("BuildingModeToolbar", buildingToolbar, 12)
        listKeys("BuildingModeToolbar.BuildModeClient", nested, 18)
        listMethods("BuildingModeToolbar.BuildModeClient", nested)
    end

    -- Show only a few other ClientState field names/types; no function dumps.
    listKeys("ClientState", state, 22)
end

log("========== END (output capped at " .. LIMIT .. " lines) ==========")
