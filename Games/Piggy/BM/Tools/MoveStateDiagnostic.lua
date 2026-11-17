-- Native Move Selection Diagnostic v4 (read-only)
-- Run in ORIGINAL Piggy Build Mode with a block selected and Move handles visible.

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local BMC = require(RS:WaitForChild("BuildMode"):WaitForChild("BuildModeClient"))

local count, LIMIT = 0, 58
local function log(v)
    if count >= LIMIT then return end
    count += 1
    print("[MoveState] " .. tostring(v))
end

local function desc(v)
    local t = typeof(v)
    if t == "Instance" then
        local ok, name = pcall(function() return v:GetFullName() end)
        return (ok and name or v.Name) .. " <" .. v.ClassName .. ">"
    end
    if type(v) == "table" then return "table" .. (getmetatable(v) and " [mt]" or "") end
    return tostring(v) .. " <" .. t .. ">"
end

local function methodTable(obj)
    if type(obj) ~= "table" then return {} end
    local mt = getmetatable(obj)
    local ix = type(mt) == "table" and rawget(mt, "__index")
    return type(ix) == "table" and ix or {}
end

local function inspectFunction(label, fn, maxConstants, maxUpvalues)
    log(label .. "=" .. desc(fn))
    if type(fn) ~= "function" then return end
    if debug and type(debug.getconstants) == "function" then
        local ok, constants = pcall(debug.getconstants, fn)
        if ok and type(constants) == "table" then
            local shown = 0
            for index, value in pairs(constants) do
                if shown >= maxConstants then break end
                if type(value) == "string" then
                    shown += 1
                    log("  C" .. tostring(index) .. "=" .. value)
                end
            end
            log("  strings=" .. shown)
        end
    end
    if debug and type(debug.getupvalues) == "function" then
        local ok, values = pcall(debug.getupvalues, fn)
        if ok and type(values) == "table" then
            local shown = 0
            for index, value in pairs(values) do
                if shown >= maxUpvalues then break end
                shown += 1
                log("  U" .. tostring(index) .. "=" .. desc(value))
            end
        end
    end
end

log("===== SELECTION FLOW DIAGNOSTIC V4 =====")
log("GUI=" .. gui:GetFullName())
if type(getgc) ~= "function" or not debug or type(debug.getupvalues) ~= "function" then
    log("Missing getgc/debug"); return
end

local okUp, up = pcall(debug.getupvalues, BMC.new)
local class = okUp and type(up) == "table" and up[3]
if not class then log("ClientState class not found"); return end
local okGc, gc = pcall(getgc, true)
if not okGc or type(gc) ~= "table" then log("getgc failed"); return end

local state
for _, obj in ipairs(gc) do
    if type(obj) == "table" then
        local okMt, mt = pcall(getmetatable, obj)
        if okMt and mt == class then state = obj; break end
    end
end
if not state then log("ClientState not found"); return end

local toolbar = rawget(state, "Toolbar")
local bt = type(toolbar) == "table" and rawget(toolbar, "BuildingModeToolbar")
local client = type(bt) == "table" and rawget(bt, "BuildModeClient")
if type(client) ~= "table" then log("Nested BuildModeClient missing"); return end

log("SelectedBlock=" .. desc(rawget(client, "SelectedBlock")))
local handles = rawget(client, "MoveHandles")
log("MoveHandles._Adornee=" .. desc(type(handles) == "table" and rawget(handles, "_Adornee")))
local box = rawget(client, "BoxSelection")
log("BoxSelection._Adornee=" .. desc(type(box) == "table" and rawget(box, "_Adornee")))

local clientMethods = methodTable(client)
inspectFunction("BuildModeClient.Mount", clientMethods.Mount, 16, 8)
inspectFunction("BuildModeClient.BindBuildActions", clientMethods.BindBuildActions, 16, 8)
inspectFunction("BuildModeClient.PlaceBlockAction", clientMethods.PlaceBlockAction, 16, 8)

local buildInput = rawget(client, "BuildInput")
log("BuildInput=" .. desc(buildInput))
if type(buildInput) == "table" then
    local names, n = {}, 0
    for k, v in pairs(buildInput) do
        n += 1
        if n <= 10 then names[#names + 1] = tostring(k) .. ":" .. typeof(v) end
    end
    log("BuildInput fields=" .. table.concat(names, " | "))
    local biMethods = methodTable(buildInput)
    local shown = 0
    for name, fn in pairs(biMethods) do
        if type(fn) == "function" and shown < 4 then
            shown += 1
            log("BuildInput method=" .. tostring(name))
        end
    end
end
log("===== END =====")
