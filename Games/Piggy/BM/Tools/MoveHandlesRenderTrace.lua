--==================================================
-- MOVE HANDLES RENDER TRACE
-- Read-only inspection of native MoveHandles render methods.
--==================================================

local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")

local ClientState
assert(type(getgc) == "function", "[MoveHandlesRenderTrace] getgc unavailable")

for attempt = 1, 100 do
    for _, object in ipairs(getgc(true)) do
        if type(object) == "table"
            and rawget(object, "ScreenGui") == BuildModeGui
            and rawget(object, "Toolbar") then
            ClientState = object
            break
        end
    end
    if ClientState then break end
    task.wait(0.1)
end

assert(ClientState, "[MoveHandlesRenderTrace] BuildModeClient not found")

local Handles = ClientState.MoveHandles
assert(type(Handles) == "table", "[MoveHandlesRenderTrace] MoveHandles not found")

local mt = getmetatable(Handles)
assert(type(mt) == "table", "[MoveHandlesRenderTrace] MoveHandles metatable not found")

local classTable
if type(debug) == "table" and type(debug.getupvalues) == "function" then
    local ok, values = pcall(debug.getupvalues, mt.Destroy)
    if ok and type(values) == "table" then
        for _, value in pairs(values) do
            if type(value) == "table"
                and type(rawget(value, "Render")) == "function"
                and type(rawget(value, "_AdorneeChanged")) == "function" then
                classTable = value
                break
            end
        end
    end
end

local function PrintInfo(label, fn)
    print("----- " .. label .. " -----")
    print("TYPE", typeof(fn), tostring(fn))
    if type(fn) ~= "function" or type(debug) ~= "table" then return end

    if type(debug.getinfo) == "function" then
        local ok, info = pcall(debug.getinfo, fn)
        if ok and type(info) == "table" then
            for _, key in ipairs({
                "what", "source", "short_src", "linedefined", "lastlinedefined",
                "nups", "nparams", "isvararg", "name", "namewhat"
            }) do
                print("INFO", key, tostring(info[key]))
            end
        else
            print("GETINFO FAILED", tostring(info))
        end
    end

    for _, method in ipairs({"getconstants", "getupvalues", "getprotos"}) do
        local inspector = debug[method]
        if type(inspector) == "function" then
            local ok, values = pcall(inspector, fn)
            print(string.upper(method), ok and typeof(values) or "ERROR", ok and tostring(values) or tostring(values))
            if ok and type(values) == "table" then
                for index, value in pairs(values) do
                    print("  ", index, typeof(value), tostring(value))
                end
            end
        end
    end
end

print("========== MOVE HANDLES RENDER TRACE ==========")
print("HANDLE ADORNEE", tostring(Handles._Adornee))
print("HANDLE IS DRAGGING", tostring(Handles.IsDragging))
print("HANDLE CLASS", tostring(classTable))

if classTable then
    PrintInfo("CLASS Render", classTable.Render)
    PrintInfo("CLASS _AdorneeChanged", classTable._AdorneeChanged)
    PrintInfo("CLASS SetAdornee", classTable.SetAdornee)
    PrintInfo("CLASS new", classTable.new)
end

PrintInfo("INSTANCE SetAdornee", mt.SetAdornee)
PrintInfo("INSTANCE Destroy", mt.Destroy)
PrintInfo("METATABLE __index", mt.__index)

print("----- ADORNMENT GEOMETRY -----")
for index, adornment in pairs(Handles._Handles or {}) do
    if typeof(adornment) == "Instance" then
        local okSize, size = pcall(function() return adornment.Size end)
        local okCFrame, cf = pcall(function() return adornment.CFrame end)
        local okZ, z = pcall(function() return adornment.ZIndex end)
        print(
            "HANDLE",
            index,
            adornment.ClassName,
            "Size",
            okSize and tostring(size) or "N/A",
            "CFrame",
            okCFrame and tostring(cf) or "N/A",
            "ZIndex",
            okZ and tostring(z) or "N/A"
        )
    end
end

print("----- HANDLE CONNECTIONS -----")
for key, connection in pairs(Handles._Connections or {}) do
    print("CONNECTION", tostring(key), typeof(connection), tostring(connection))
    if type(connection) == "table" then
        for field, value in pairs(connection) do
            if type(value) == "function" then
                PrintInfo("CONNECTION " .. tostring(key) .. "." .. tostring(field), value)
            elseif field ~= "Connected" then
                print("  FIELD", tostring(field), typeof(value), tostring(value))
            end
        end
    end
end

print("========== END MOVE HANDLES TRACE ==========")
