--==================================================
-- MOVE DRAG CLASS DIAGNOSTIC
-- Inspects the native Drag class used by BuildModeClient.
-- Read-only: does not call Drag.new/Drag/Reset and does
-- not modify SelectedBlock, MoveHandles, or BuildMode.
--==================================================

local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")

local function Log(...)
    print("[MoveDragClassDiagnostic]", ...)
end

local function GetDebugFunction(name)
    if type(debug) == "table" and type(debug[name]) == "function" then
        return debug[name]
    end
    if type(getfenv) == "function" then
        local env = getfenv(0)
        if type(env[name]) == "function" then return env[name] end
    end
    return nil
end

local getinfo = GetDebugFunction("getinfo") or getinfo
local getupvalue = GetDebugFunction("getupvalue") or getupvalue
local getconstants = GetDebugFunction("getconstants") or getconstants
local getconnections = GetDebugFunction("getconnections") or getconnections

assert(type(getconnections) == "function", "getconnections unavailable")
assert(type(getinfo) == "function", "debug.getinfo unavailable")

local ClientState
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

assert(ClientState, "BuildModeClient ClientState not found")
local MoveHandles = ClientState.MoveHandles
assert(MoveHandles, "MoveHandles unavailable")

local function DescribeValue(value)
    local kind = typeof(value)
    if kind == "Instance" then
        local ok, fullName = pcall(function() return value:GetFullName() end)
        return ok and fullName or tostring(value)
    end
    if type(value) == "table" then
        local keys = {}
        for key in pairs(value) do
            keys[#keys + 1] = tostring(key)
            if #keys >= 20 then break end
        end
        table.sort(keys)
        return "table keys={" .. table.concat(keys, ", ") .. "}"
    end
    return tostring(value)
end

local function InspectFunction(label, fn)
    if type(fn) ~= "function" then
        Log(label, "not a function:", typeof(fn), DescribeValue(fn))
        return
    end

    local okInfo, info = pcall(getinfo, fn)
    Log("========== FUNCTION:", label, "==========")
    if okInfo and info then
        Log("Source:", info.source or info.short_src)
        Log("Name:", info.name)
        Log("Line:", info.linedefined, "-", info.lastlinedefined)
        Log("What:", info.what)
        Log("Nups:", info.nups)
    else
        Log("getinfo failed:", info)
    end

    if type(getupvalue) == "function" then
        for index = 1, 20 do
            local ok, name, value = pcall(getupvalue, fn, index)
            if not ok or name == nil then break end
            Log("Upvalue", index, "name=", name, "type=", typeof(value), "value=", DescribeValue(value))
        end
    else
        Log("getupvalue unavailable")
    end

    if type(getconstants) == "function" then
        local ok, constants = pcall(getconstants, fn)
        if ok and type(constants) == "table" then
            for index, value in ipairs(constants) do
                Log("Constant", index, "=", tostring(value))
            end
        else
            Log("getconstants failed/unavailable:", constants)
        end
    else
        Log("getconstants unavailable")
    end
end

Log("ClientState found:", tostring(ClientState))
Log("SelectedBlock:", DescribeValue(ClientState.SelectedBlock))
Log("MoveHandles._Adornee:", DescribeValue(MoveHandles._Adornee))

local dragClass
local ok, connections = pcall(getconnections, MoveHandles.MouseDrag)
assert(ok and type(connections) == "table", "Could not inspect MoveHandles.MouseDrag connections")

for index, connection in ipairs(connections) do
    local fn = connection.Function or connection.FunctionRef
    if type(fn) == "function" then
        local infoOk, info = pcall(getinfo, fn)
        if infoOk and info and info.source == "=ReplicatedStorage.BuildMode.BuildModeClient" then
            local count = info.nups or 0
            for upIndex = 1, count do
                local upOk, upName, value = pcall(getupvalue, fn, upIndex)
                if upOk and type(value) == "table"
                    and type(rawget(value, "new")) == "function"
                    and type(rawget(value, "Drag")) == "function"
                    and type(rawget(value, "Reset")) == "function" then
                    dragClass = value
                    Log("Found native Drag class in MouseDrag connection", index, "upvalue", upIndex, upName)
                    break
                end
            end
        end
    end
    if dragClass then break end
end

assert(dragClass, "Native Drag class not found in BuildModeClient MouseDrag handler")

Log("Drag class:", DescribeValue(dragClass))
InspectFunction("Drag.new", dragClass.new)
InspectFunction("Drag.Drag", dragClass.Drag)
InspectFunction("Drag.Reset", dragClass.Reset)

Log("========== END ==========")
Log("No functions were called and no BuildMode values were modified.")
