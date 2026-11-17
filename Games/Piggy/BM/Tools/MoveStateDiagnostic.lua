-- Native Move Selection Diagnostic v5 (read-only)
-- Run in ORIGINAL Piggy Build Mode with a block selected and Move handles visible.

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local BMC = require(RS:WaitForChild("BuildMode"):WaitForChild("BuildModeClient"))

local count, LIMIT = 0, 88
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

log("===== SELECTION FLOW DIAGNOSTIC V5 =====")
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

local buildInput = rawget(client, "BuildInput")
log("BuildInput=" .. desc(buildInput))
if type(buildInput) == "table" then
    local list = rawget(buildInput, "_List")
    local callbacks = rawget(buildInput, "_CustomCallbacks")
    log("BuildInput._List=" .. desc(list))
    if type(list) == "table" then
        local shown = 0
        for k, v in pairs(list) do
            if shown >= 12 then break end
            shown += 1
            log("  List[" .. tostring(k) .. "]=" .. desc(v))
            if type(v) == "table" then
                local fields, n = {}, 0
                for a, b in pairs(v) do
                    n += 1
                    if n <= 7 then fields[#fields + 1] = tostring(a) .. ":" .. desc(b) end
                end
                log("    fields=" .. table.concat(fields, " | "))
            end
        end
        log("  List entries shown=" .. shown)
    end
    log("BuildInput._CustomCallbacks=" .. desc(callbacks))
    if type(callbacks) == "table" then
        local shown = 0
        for k, v in pairs(callbacks) do
            if shown >= 16 then break end
            shown += 1
            log("  Callback[" .. tostring(k) .. "]=" .. desc(v))
            if type(v) == "function" then
                inspectFunction("    CallbackFn", v, 5, 4)
            elseif type(v) == "table" then
                local fields, n = {}, 0
                for a, b in pairs(v) do
                    n += 1
                    if n <= 5 then fields[#fields + 1] = tostring(a) .. ":" .. desc(b) end
                end
                log("    fields=" .. table.concat(fields, " | "))
            end
        end
        log("  Callback entries shown=" .. shown)
    end
    local methods = methodTable(buildInput)
    for _, name in ipairs({"AddItem", "AddItems", "AddSweepSignal", "Sweep"}) do
        inspectFunction("BuildInput." .. name, methods[name], 8, 5)
    end
end

local modes = RS:FindFirstChild("BuildMode") and RS.BuildMode:FindFirstChild("Modes")
log("ModesFolder=" .. desc(modes))
if modes then
    for _, child in ipairs(modes:GetChildren()) do
        log("ModeChild=" .. child.Name .. " <" .. child.ClassName .. ">")
    end
end
log("===== END =====")
