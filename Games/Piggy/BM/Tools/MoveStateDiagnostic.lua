-- Native Move Selection Diagnostic v13 (read-only, targeted modules only)
local RS = game:GetService("ReplicatedStorage")
local root = RS:WaitForChild("BuildMode")
local output, LIMIT = 0, 120

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
    return type(v)
end

local function upvalues(label, fn, depth)
    if type(fn) ~= "function" then return end
    if not debug or type(debug.getupvalues) ~= "function" then
        log(label .. ": debug.getupvalues unavailable")
        return
    end
    local ok, values = pcall(debug.getupvalues, fn)
    if not ok or type(values) ~= "table" then
        log(label .. ": getupvalues failed " .. tostring(values))
        return
    end
    for i, value in pairs(values) do
        log(label .. " U" .. tostring(i) .. "=" .. desc(value))
        if type(value) == "table" then
            local matches = {}
            for _, key in ipairs({"SelectedBlock","MoveHandles","BoxSelection","Toolbar","BuildModeClient","BuildingModeToolbar","Placement"}) do
                local found = raw(value, key)
                if found ~= nil then matches[#matches+1] = key .. "=" .. desc(found) end
            end
            if #matches > 0 then log(label .. " MATCH " .. table.concat(matches, " ; ")) end
            if depth and depth > 0 then
                local mt = getmetatable(value)
                local idx = type(mt) == "table" and raw(mt, "__index") or nil
                if type(idx) == "table" then
                    for _, methodName in ipairs({"Mount","BindBuildActions","PlaceBlockAction","Update","Action"}) do
                        local method = raw(idx, methodName)
                        if type(method) == "function" then
                            log(label .. " METHOD " .. methodName)
                            upvalues(label .. "." .. methodName, method, depth - 1)
                        end
                    end
                end
            end
        end
    end
end

local function inspectModule(name)
    local module = root:FindFirstChild(name)
    if not module or not module:IsA("ModuleScript") then
        log("MODULE MISSING " .. name)
        return
    end
    local ok, result = pcall(require, module)
    log("MODULE " .. name .. " require=" .. tostring(ok) .. " result=" .. desc(result))
    if not ok or type(result) ~= "table" then return end
    for key, value in pairs(result) do
        log(name .. "." .. tostring(key) .. "=" .. desc(value))
        if type(value) == "function" and (key == "new" or key == "Mount" or key == "BindBuildActions"
            or key == "PlaceBlockAction" or key == "Update" or key == "Action") then
            upvalues(name .. "." .. tostring(key), value, 1)
        end
    end
    local mt = getmetatable(result)
    local idx = type(mt) == "table" and raw(mt, "__index") or nil
    if type(idx) == "table" then
        for key, value in pairs(idx) do
            if type(value) == "function" then
                log(name .. ".__index." .. tostring(key) .. "=function")
                if key == "Mount" or key == "BindBuildActions" or key == "PlaceBlockAction" then
                    upvalues(name .. ".__index." .. tostring(key), value, 1)
                end
            end
        end
    end
end

log("===== TARGETED MODULE DIAGNOSTIC V13 =====")
for _, name in ipairs({"BuildModeClient","Toolbar","BuildingModeToolbar","BuildingMode","RenderLoop","Placement"}) do
    inspectModule(name)
end

local modes = root:FindFirstChild("Modes")
local move = modes and modes:FindFirstChild("Move")
if move then
    local ok, result = pcall(require, move)
    log("MODULE Modes.Move require=" .. tostring(ok) .. " result=" .. desc(result))
    if ok and type(result) == "table" then
        for _, key in ipairs({"Init","Enter","Update","Action","Exit"}) do
            local fn = raw(result, key)
            log("Modes.Move." .. key .. "=" .. desc(fn))
            upvalues("Modes.Move." .. key, fn, 0)
        end
    end
end
log("===== END V13 =====")
