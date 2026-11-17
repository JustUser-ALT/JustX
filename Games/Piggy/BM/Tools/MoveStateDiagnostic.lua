-- Native Move Selection Diagnostic v11 (read-only)
-- Uses known GUI/ReplicatedStorage references and debug upvalues; no getgc required.

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local root = RS:FindFirstChild("BuildMode")

local count, LIMIT = 0, 170
local function log(v)
    if count >= LIMIT then return end
    count += 1
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

local function listChildren(parent, label, depth)
    if not parent then return end
    for _, child in ipairs(parent:GetChildren()) do
        if depth == 0 or string.find(string.lower(child.Name), "buildmode", 1, true)
            or string.find(string.lower(child.Name), "toolbar", 1, true)
            or string.find(string.lower(child.Name), "client", 1, true) then
            log(label .. child.Name .. " <" .. child.ClassName .. ">")
        end
        if depth > 0 then listChildren(child, label .. child.Name .. ".", depth - 1) end
    end
end

local function inspectUpvalues(label, fn)
    if type(fn) ~= "function" or not debug or type(debug.getupvalues) ~= "function" then
        log(label .. " upvalues unavailable")
        return
    end
    local ok, ups = pcall(debug.getupvalues, fn)
    if not ok or type(ups) ~= "table" then
        log(label .. " getupvalues failed: " .. tostring(ups))
        return
    end
    for i, value in pairs(ups) do
        log(label .. " U" .. tostring(i) .. "=" .. desc(value))
        if type(value) == "table" then
            local mt = getmetatable(value)
            local idx = type(mt) == "table" and raw(mt, "__index") or nil
            local fields = {}
            for _, key in ipairs({"SelectedBlock","MoveHandles","BoxSelection","Toolbar","BuildModeClient","BuildingModeToolbar"}) do
                local v = raw(value, key)
                if v ~= nil then fields[#fields+1] = key .. "=" .. desc(v) end
            end
            if #fields > 0 then log("  MATCH " .. table.concat(fields, " ; ")) end
            if type(idx) == "table" then
                for _, key in ipairs({"Mount","BindBuildActions","PlaceBlockAction","Update","Action"}) do
                    local method = raw(idx, key)
                    if type(method) == "function" then
                        log("  METHOD " .. key .. "=" .. desc(method))
                        if key == "PlaceBlockAction" or key == "BindBuildActions" then
                            inspectUpvalues(label .. "." .. key, method)
                        end
                    end
                end
            end
        end
    end
end

log("===== KNOWN REFERENCE DIAGNOSTIC V11 =====")
log("GUI=" .. gui:GetFullName())
log("----- GUI relevant descendants -----")
listChildren(gui, "GUI.", 4)
log("----- ReplicatedStorage.BuildMode descendants -----")
listChildren(root, "BuildMode.", 4)

if root then
    local modes = root:FindFirstChild("Modes")
    local move = modes and modes:FindFirstChild("Move")
    if move and type(require) == "function" then
        local ok, exported = pcall(require, move)
        log("Move require=" .. tostring(ok) .. " " .. desc(exported))
        if ok and type(exported) == "table" then
            for _, key in ipairs({"Init","Enter","Update","Action","Exit"}) do
                inspectUpvalues("Move." .. key, raw(exported, key))
            end
        end
    end
end

if type(getloadedmodules) == "function" then
    local ok, modules = pcall(getloadedmodules)
    log("getloadedmodules=" .. tostring(ok) .. " " .. desc(modules))
    if ok and type(modules) == "table" then
        for _, module in ipairs(modules) do
            if typeof(module) == "Instance" and (string.find(string.lower(module.Name), "buildmode", 1, true)
                or string.find(string.lower(module.Name), "toolbar", 1, true)) then
                log("LOADED MODULE=" .. desc(module))
            end
        end
    end
else
    log("getloadedmodules unavailable")
end
log("===== END =====")
