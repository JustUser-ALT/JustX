-- Native Move Selection Diagnostic (focused, read-only)
-- Run in ORIGINAL Piggy Build Mode with a block selected and Move handles visible.

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local BMC = require(RS:WaitForChild("BuildMode"):WaitForChild("BuildModeClient"))

local lines, LIMIT = 0, 48
local function log(v)
    if lines >= LIMIT then return end
    lines += 1
    print("[MoveState] " .. tostring(v))
end

local function desc(v)
    local t = typeof(v)
    if t == "Instance" then
        local ok, n = pcall(function() return v:GetFullName() end)
        return (ok and n or v.Name) .. " <" .. v.ClassName .. ">"
    end
    return t == "table" and ("table" .. (getmetatable(v) and " [mt]" or "")) or (t == "function" and "function" or tostring(v) .. " <" .. t .. ">")
end

local function inspect(label, obj, maxKeys, maxMethods)
    log(label .. " = " .. desc(obj))
    if type(obj) ~= "table" then return end
    local n = 0
    for k, v in pairs(obj) do
        n += 1
        if n <= maxKeys then log("  ." .. tostring(k) .. " : " .. typeof(v)) end
    end
    if n > maxKeys then log("  fields truncated; total=" .. n) end
    local mt = getmetatable(obj)
    local ix = type(mt) == "table" and rawget(mt, "__index")
    local src = type(ix) == "table" and ix or (type(mt) == "table" and mt)
    if type(src) == "table" then
        local m = 0
        for k, v in pairs(src) do
            if type(v) == "function" then
                m += 1
                if m <= maxMethods then log("  method: " .. tostring(k)) end
            end
        end
        log("  methods total=" .. m)
    else
        log("  method source=" .. desc(ix))
    end
end

log("===== FOCUSED SELECTION DIAGNOSTIC =====")
log("GUI=" .. gui:GetFullName())
if type(getgc) ~= "function" or not debug or type(debug.getupvalues) ~= "function" then
    log("Missing getgc/debug.getupvalues")
    return
end

local ok, up = pcall(debug.getupvalues, BMC.new)
local class = ok and type(up) == "table" and up[3]
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
if not state then log("ClientState instance not found"); return end

log("ClientState.SelectedBlock=" .. desc(rawget(state, "SelectedBlock")))
local outerHandles = rawget(state, "MoveHandles")
log("ClientState.MoveHandles._Adornee=" .. desc(type(outerHandles) == "table" and rawget(outerHandles, "_Adornee")))
local toolbar = rawget(state, "Toolbar")
local buildingToolbar = type(toolbar) == "table" and rawget(toolbar, "BuildingModeToolbar")
local client = type(buildingToolbar) == "table" and rawget(buildingToolbar, "BuildModeClient")
log("Nested BuildModeClient=" .. desc(client))
if type(client) ~= "table" then log("Nested client unavailable"); return end

log("Nested.SelectedBlock=" .. desc(rawget(client, "SelectedBlock")))
local handles = rawget(client, "MoveHandles")
log("Nested.MoveHandles._Adornee=" .. desc(type(handles) == "table" and rawget(handles, "_Adornee")))
inspect("Nested.MoveHandles", handles, 5, 8)
inspect("Nested.BoxSelection", rawget(client, "BoxSelection"), 10, 12)
inspect("Nested.SurfaceSelection", rawget(client, "SurfaceSelection"), 10, 12)
inspect("Nested.Placement", rawget(client, "Placement"), 8, 8)
log("===== END =====")
