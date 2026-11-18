--==================================================
-- MOVE DRAG CLASS INSPECTOR
-- Delta-compatible getupvalue handling.
-- Reads the Drag class from BuildModeClient MouseDrag
-- callback upvalue 3, as identified by prior diagnostics.
-- Read-only: does not call class methods or mutate state.
--==================================================

local Players = game:GetService("Players")
local BuildModeGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")

local function Log(...) print("[MoveDragClassInspector]", ...) end
local function DebugFunction(name)
    if type(debug) == "table" and type(debug[name]) == "function" then
        return debug[name]
    end
    return nil
end

local getinfo = DebugFunction("getinfo") or getinfo
local getupvalue = DebugFunction("getupvalue") or getupvalue
local getconstants = DebugFunction("getconstants") or getconstants
local getconnections = DebugFunction("getconnections") or getconnections

assert(type(getinfo) == "function", "debug.getinfo unavailable")
assert(type(getupvalue) == "function", "debug.getupvalue unavailable")
assert(type(getconnections) == "function", "getconnections unavailable")

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

local Handles = ClientState.MoveHandles
assert(Handles, "MoveHandles unavailable")

local ok, connections = pcall(getconnections, Handles.MouseDrag)
assert(ok and type(connections) == "table", "Could not inspect MouseDrag connections")

local function ReadUpvalue(fn, index)
    local result = table.pack(pcall(getupvalue, fn, index))
    if not result[1] then return nil end

    -- Delta's getupvalue may return only the value.
    -- Standard debug.getupvalue returns name, value.
    if result.n >= 3 then
        return result[3]
    elseif result.n == 2 then
        return result[2]
    end
    return nil
end

local dragClass
local sourceConnection

for connectionIndex, connection in ipairs(connections) do
    local fn = connection.Function or connection.FunctionRef
    if type(fn) == "function" then
        local infoOk, info = pcall(getinfo, fn)
        if infoOk and info and (info.source == "=ReplicatedStorage.BuildMode.BuildModeClient"
            or tostring(info.source):find("BuildModeClient", 1, true)) then
            Log("BuildModeClient MouseDrag connection:", connectionIndex)
            Log("Source:", info.source, "Nups:", info.nups)

            for upIndex = 1, (info.nups or 0) do
                local value = ReadUpvalue(fn, upIndex)
                local keys = {}
                if type(value) == "table" then
                    for key in pairs(value) do
                        keys[#keys + 1] = tostring(key)
                    end
                    table.sort(keys)
                end
                Log("Upvalue", upIndex, "type=", typeof(value),
                    "value=", type(value) == "table" and ("keys={" .. table.concat(keys, ", ") .. "}") or tostring(value))

                if type(value) == "table"
                    and type(rawget(value, "new")) == "function"
                    and type(rawget(value, "Drag")) == "function"
                    and type(rawget(value, "Reset")) == "function" then
                    dragClass = value
                    sourceConnection = connectionIndex
                    break
                end
            end
        end
    end
    if dragClass then break end
end

assert(dragClass, "Drag class not found; Delta upvalue return format may differ")

Log("FOUND Drag class in MouseDrag connection", sourceConnection)

local function InspectMethod(name)
    local fn = rawget(dragClass, name)
    Log("========== METHOD", name, "==========")
    local infoOk, info = pcall(getinfo, fn)
    if infoOk and info then
        Log("Function:", tostring(fn))
        Log("Source:", info.source or info.short_src)
        Log("Name:", info.name)
        Log("Line:", info.linedefined, "-", info.lastlinedefined)
        Log("What:", info.what)
        Log("Nups:", info.nups)
    else
        Log("getinfo failed:", info)
    end

    for index = 1, (infoOk and info and info.nups or 0) do
        local value = ReadUpvalue(fn, index)
        local keys = {}
        if type(value) == "table" then
            for key in pairs(value) do
                keys[#keys + 1] = tostring(key)
            end
            table.sort(keys)
        end
        Log("Upvalue", index, "type=", typeof(value),
            "value=", type(value) == "table" and ("keys={" .. table.concat(keys, ", ") .. "}") or tostring(value))
    end

    if type(getconstants) == "function" then
        local cOk, constants = pcall(getconstants, fn)
        if cOk and type(constants) == "table" then
            for index, value in ipairs(constants) do
                Log("Constant", index, "=", tostring(value))
            end
        else
            Log("getconstants unavailable/failed:", constants)
        end
    end
end

InspectMethod("new")
InspectMethod("Drag")
InspectMethod("Reset")

Log("========== END; READ-ONLY ==========")
Log("No Drag methods were called and no BuildMode values were modified.")
