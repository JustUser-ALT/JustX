-- Native Move Selection Diagnostic v8 (read-only)
-- Run in ORIGINAL Piggy Build Mode with a block selected and Move active.

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")

local count, LIMIT = 0, 150
local function log(v)
    if count >= LIMIT then return end
    count += 1
    print("[MoveState] " .. tostring(v))
end

local function describe(v)
    if typeof(v) == "Instance" then
        local ok, full = pcall(function() return v:GetFullName() end)
        return (ok and full or v.Name) .. " <" .. v.ClassName .. ">"
    end
    if type(v) == "table" then return "table" .. (getmetatable(v) and " [mt]" or "") end
    return tostring(v) .. " <" .. typeof(v) .. ">"
end

local function getClientState()
    local root = RS:FindFirstChild("BuildMode")
    local clientModule = root and root:FindFirstChild("BuildModeClient")
    if clientModule and type(require) == "function" then
        local ok, class = pcall(require, clientModule)
        if ok and type(class) == "table" then
            local ctor = class.new
            if type(ctor) == "function" and debug and type(debug.getupvalues) == "function" then
                local good, ups = pcall(debug.getupvalues, ctor)
                if good and type(ups) == "table" then
                    for _, value in pairs(ups) do
                        if type(value) == "table" and value.Toolbar then return value end
                    end
                end
            end
        end
    end
    if debug and type(debug.getgc) == "function" then
        local ok, objects = pcall(debug.getgc, true)
        if ok and type(objects) == "table" then
            for _, value in ipairs(objects) do
                if type(value) == "table" and value.SelectedBlock ~= nil and value.Toolbar then return value end
            end
        end
    end
end

local function inspectSource(label, fn)
    if type(fn) ~= "function" then return end
    log("----- SOURCE " .. label .. " -----")
    if type(decompile) ~= "function" then log("decompile unavailable"); return end
    local ok, source = pcall(decompile, fn)
    if not ok or type(source) ~= "string" then
        log("decompile failed: " .. tostring(source))
        return
    end
    local lines = string.split(source, "\n")
    local selected = {}
    for i, line in ipairs(lines) do
        local low = string.lower(line)
        if string.find(low, "action", 1, true)
            or string.find(low, "selectedblock", 1, true)
            or string.find(low, "currentmode", 1, true)
            or string.find(low, "mode", 1, true)
            or string.find(low, "enter", 1, true)
            or string.find(low, "update", 1, true)
            or string.find(low, "require", 1, true) then
            for n = math.max(1, i - 1), math.min(#lines, i + 1) do selected[n] = lines[n] end
        end
    end
    local emitted = {}
    for i = 1, #lines do
        if selected[i] and not emitted[i] then
            emitted[i] = true
            local line = lines[i]
            if #line > 220 then line = string.sub(line, 1, 220) .. "..." end
            log(label .. ":" .. i .. ": " .. line)
        end
    end
    if next(selected) == nil then log("No matching source lines") end
end

local function inspectMethods(label, object)
    if type(object) ~= "table" then log(label .. " unavailable: " .. describe(object)); return end
    local mt = getmetatable(object)
    local index = mt and mt.__index
    log(label .. " object=" .. describe(object))
    log(label .. " metatable.__index=" .. describe(index))
    if type(index) == "table" then
        for name, fn in pairs(index) do
            if type(fn) == "function" then
                log(label .. " method=" .. tostring(name))
                if name == "BindBuildActions" or name == "PlaceBlockAction"
                    or name == "Mount" or name == "Update" or name == "SetMode"
                    or name == "ChangeMode" or name == "SwitchMode" then
                    inspectSource(label .. "." .. tostring(name), fn)
                end
            end
        end
    end
end

log("===== ACTION CALLER DIAGNOSTIC V8 =====")
log("GUI=" .. gui:GetFullName())
local state = getClientState()
log("ClientState=" .. describe(state))
if state then
    log("SelectedBlock=" .. describe(state.SelectedBlock))
    local toolbar = state.Toolbar
    log("Toolbar=" .. describe(toolbar))
    local buildingToolbar = type(toolbar) == "table" and toolbar.BuildingModeToolbar
    log("BuildingModeToolbar=" .. describe(buildingToolbar))
    local client = type(buildingToolbar) == "table" and buildingToolbar.BuildModeClient
    log("Nested BuildModeClient=" .. describe(client))
    inspectMethods("BuildModeClient", client)
    inspectMethods("BuildingModeToolbar", buildingToolbar)
else
    log("ClientState lookup failed")
end
log("===== END =====")
