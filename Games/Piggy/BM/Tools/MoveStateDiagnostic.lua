-- Native Move Selection Diagnostic v9 (read-only)
-- Avoids Enumeration.__index by using rawget on inspected tables.

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")

local count, LIMIT = 0, 150
local function log(v)
    if count >= LIMIT then return end
    count += 1
    print("[MoveState] " .. tostring(v))
end

local function safeRaw(t, key)
    if type(t) ~= "table" then return nil end
    local ok, value = pcall(rawget, t, key)
    return ok and value or nil
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
    if clientModule then
        local ok, class = pcall(require, clientModule)
        if ok and type(class) == "table" then
            local ctor = safeRaw(class, "new")
            if type(ctor) == "function" and debug and type(debug.getupvalues) == "function" then
                local good, ups = pcall(debug.getupvalues, ctor)
                if good and type(ups) == "table" then
                    for _, value in pairs(ups) do
                        if type(value) == "table" then
                            local toolbar = safeRaw(value, "Toolbar")
                            local selected = safeRaw(value, "SelectedBlock")
                            if toolbar ~= nil or selected ~= nil then
                                return value, "BuildModeClient.new upvalue"
                            end
                        end
                    end
                end
            end
        end
    end

    if debug and type(debug.getgc) == "function" then
        local ok, objects = pcall(debug.getgc, true)
        if ok and type(objects) == "table" then
            for _, value in ipairs(objects) do
                if type(value) == "table" then
                    local toolbar = safeRaw(value, "Toolbar")
                    local selected = safeRaw(value, "SelectedBlock")
                    if toolbar ~= nil and selected ~= nil then
                        return value, "GC table with raw Toolbar and SelectedBlock"
                    end
                end
            end
        end
    end
    return nil, "not found"
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
    local emitted = false
    for i = 1, #lines do
        if selected[i] then
            emitted = true
            local line = lines[i]
            if #line > 220 then line = string.sub(line, 1, 220) .. "..." end
            log(label .. ":" .. i .. ": " .. line)
        end
    end
    if not emitted then log("No matching source lines") end
end

local function inspectMethods(label, object)
    if type(object) ~= "table" then log(label .. " unavailable: " .. describe(object)); return end
    local mt = getmetatable(object)
    local index = type(mt) == "table" and safeRaw(mt, "__index") or nil
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

log("===== ACTION CALLER DIAGNOSTIC V9 =====")
log("GUI=" .. gui:GetFullName())
local state, source = getClientState()
log("ClientState source=" .. source)
log("ClientState=" .. describe(state))
if state then
    local selected = safeRaw(state, "SelectedBlock")
    local toolbar = safeRaw(state, "Toolbar")
    log("SelectedBlock=" .. describe(selected))
    log("Toolbar=" .. describe(toolbar))
    local buildingToolbar = safeRaw(toolbar, "BuildingModeToolbar")
    log("BuildingModeToolbar=" .. describe(buildingToolbar))
    local client = safeRaw(buildingToolbar, "BuildModeClient")
    log("Nested BuildModeClient=" .. describe(client))
    inspectMethods("BuildModeClient", client)
    inspectMethods("BuildingModeToolbar", buildingToolbar)
else
    log("ClientState lookup failed safely; no state was modified")
end
log("===== END =====")
