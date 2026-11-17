-- Native Move Selection Diagnostic v12 (read-only)
-- Quiet scan: only relevant scripts/modules and BuildMode references.

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local root = RS:FindFirstChild("BuildMode")
local output = 0
local LIMIT = 100

local function log(v)
    if output >= LIMIT then return end
    output += 1
    print("[MoveState] " .. tostring(v))
end

local function raw(t, k)
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(rawget, t, k)
    return ok and v or nil
end

local function desc(v)
    if typeof(v) == "Instance" then
        local ok, p = pcall(function() return v:GetFullName() end)
        return (ok and p or v.Name) .. " <" .. v.ClassName .. ">"
    end
    if type(v) == "table" then return "table" .. (getmetatable(v) and " [mt]" or "") end
    return tostring(v) .. " <" .. typeof(v) .. ">"
end

local function inspectUpvalues(label, fn, recurse)
    if type(fn) ~= "function" or not debug or type(debug.getupvalues) ~= "function" then
        log(label .. ": upvalues unavailable")
        return
    end
    local ok, ups = pcall(debug.getupvalues, fn)
    if not ok or type(ups) ~= "table" then
        log(label .. ": getupvalues failed " .. tostring(ups))
        return
    end
    for i, value in pairs(ups) do
        log(label .. " U" .. tostring(i) .. "=" .. desc(value))
        if type(value) == "table" then
            local fields = {}
            for _, key in ipairs({"SelectedBlock","MoveHandles","BoxSelection","Toolbar","BuildModeClient","BuildingModeToolbar"}) do
                local v = raw(value, key)
                if v ~= nil then fields[#fields+1] = key .. "=" .. desc(v) end
            end
            if #fields > 0 then log(label .. " MATCH " .. table.concat(fields, " ; ")) end
            local mt = getmetatable(value)
            local idx = type(mt) == "table" and raw(mt, "__index") or nil
            if recurse and type(idx) == "table" then
                for _, key in ipairs({"Mount","BindBuildActions","PlaceBlockAction","Update","Action"}) do
                    local method = raw(idx, key)
                    if type(method) == "function" then
                        log(label .. " METHOD " .. key)
                        if key == "PlaceBlockAction" or key == "BindBuildActions" then
                            inspectUpvalues(label .. "." .. key, method, false)
                        end
                    end
                end
            end
        end
    end
end

local function scan(parent, prefix)
    if not parent then return end
    for _, obj in ipairs(parent:GetDescendants()) do
        local class = obj.ClassName
        local name = string.lower(obj.Name)
        local relevantName = string.find(name, "buildmode", 1, true)
            or string.find(name, "toolbar", 1, true)
            or string.find(name, "client", 1, true)
            or string.find(name, "move", 1, true)
        local isCode = class == "ModuleScript" or class == "LocalScript" or class == "Script"
        if isCode or relevantName then
            log(prefix .. obj:GetFullName() .. " <" .. class .. ">")
        end
    end
end

log("===== QUIET REFERENCE DIAGNOSTIC V12 =====")
log("GUI=" .. gui:GetFullName())
log("BuildMode root=" .. desc(root))
log("----- Relevant GUI scripts/names -----")
scan(gui, "GUI ")
log("----- Relevant ReplicatedStorage scripts/names -----")
scan(root, "RS ")

if root then
    local modes = root:FindFirstChild("Modes")
    local move = modes and modes:FindFirstChild("Move")
    if move then
        local ok, exported = pcall(require, move)
        log("Move require=" .. tostring(ok) .. " " .. desc(exported))
        if ok and type(exported) == "table" then
            for _, key in ipairs({"Init","Enter","Update","Action","Exit"}) do
                inspectUpvalues("Move." .. key, raw(exported, key), false)
            end
        end
    end
end

if type(getloadedmodules) == "function" then
    local ok, modules = pcall(getloadedmodules)
    log("getloadedmodules=" .. tostring(ok) .. " " .. desc(modules))
    if ok and type(modules) == "table" then
        for _, module in ipairs(modules) do
            if typeof(module) == "Instance" then
                local n = string.lower(module.Name)
                if string.find(n, "buildmode", 1, true) or string.find(n, "toolbar", 1, true)
                    or string.find(n, "move", 1, true) then
                    log("LOADED " .. desc(module))
                end
            end
        end
    end
else
    log("getloadedmodules unavailable")
end
log("===== END V12 =====")
