-- Native Move Selection Diagnostic v2 (read-only)
-- Run in ORIGINAL Piggy Build Mode with a block selected and Move handles visible.

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local BMC = require(RS:WaitForChild("BuildMode"):WaitForChild("BuildModeClient"))

local count, LIMIT = 0, 42
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

local function methods(obj)
    if type(obj) ~= "table" then return {} end
    local mt = getmetatable(obj)
    local ix = type(mt) == "table" and rawget(mt, "__index")
    return type(ix) == "table" and ix or {}
end

local function inspectMethods(label, obj)
    local src = methods(obj)
    log(label .. " methods:")
    local n = 0
    for name, fn in pairs(src) do
        if type(fn) == "function" then
            n += 1
            if n <= 10 then log("  " .. tostring(name)) end
            if debug and type(debug.getconstants) == "function" then
                local ok, constants = pcall(debug.getconstants, fn)
                if ok and type(constants) == "table" then
                    local hits, shown = {}, 0
                    for _, value in pairs(constants) do
                        if type(value) == "string" and (value:find("SelectedBlock", 1, true) or value:find("Adornee", 1, true) or value:find("MoveHandles", 1, true) or value:find("BoxSelection", 1, true) or value:find("Selection", 1, true) or value:find("SetAdornee", 1, true) or value:find("MouseDrag", 1, true)) then
                            if shown < 4 then hits[#hits + 1] = value; shown += 1 end
                        end
                    end
                    if #hits > 0 then log("    refs[" .. tostring(name) .. "]=" .. table.concat(hits, ", ")) end
                end
            end
        end
    end
    log("  total=" .. n)
end

log("===== SELECTION FLOW DIAGNOSTIC V2 =====")
log("GUI=" .. gui:GetFullName())
if type(getgc) ~= "function" or not debug or type(debug.getupvalues) ~= "function" then
    log("Missing getgc/debug")
    return
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
log("BoxSelection._Instance=" .. desc(type(box) == "table" and rawget(box, "_Instance")))
local surface = rawget(client, "SurfaceSelection")
log("SurfaceSelection._Instance=" .. desc(type(surface) == "table" and rawget(surface, "_Instance")))

local keys, n = {}, 0
for k, v in pairs(client) do
    n += 1
    if n <= 14 then keys[#keys + 1] = tostring(k) .. ":" .. typeof(v) end
end
log("BuildModeClient fields=" .. table.concat(keys, " | "))

inspectMethods("BuildModeClient", client)
inspectMethods("MoveHandles", handles)
inspectMethods("BoxSelection", box)
log("===== END =====")
