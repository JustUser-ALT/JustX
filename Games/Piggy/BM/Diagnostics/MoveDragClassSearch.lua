--==================================================
-- MOVE DRAG CLASS SEARCH
-- Searches all MoveHandles signal callbacks and their
-- direct upvalues for the native Drag class.
-- Read-only: does not call Drag methods or mutate state.
--==================================================

local Players = game:GetService("Players")
local BuildModeGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local function Log(...) print("[MoveDragClassSearch]", ...) end

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

local Signals = {
    {"MouseButton1Down", Handles.MouseButton1Down},
    {"MouseDrag", Handles.MouseDrag},
    {"MouseButton1Up", Handles.MouseButton1Up}
}

local found = {}
local function IsDragClass(value)
    return type(value) == "table"
        and type(rawget(value, "new")) == "function"
        and type(rawget(value, "Drag")) == "function"
        and type(rawget(value, "Reset")) == "function"
end

local function Describe(value)
    if type(value) == "table" then
        local keys = {}
        for key in pairs(value) do
            keys[#keys + 1] = tostring(key)
            if #keys >= 25 then break end
        end
        table.sort(keys)
        return "table keys={" .. table.concat(keys, ", ") .. "}"
    end
    return typeof(value) .. " " .. tostring(value)
end

for _, signalInfo in ipairs(Signals) do
    local signalName, signal = signalInfo[1], signalInfo[2]
    Log("========== SIGNAL", signalName, "==========")
    local ok, connections = pcall(getconnections, signal)
    if not ok or type(connections) ~= "table" then
        Log("getconnections failed:", connections)
        continue
    end

    Log("Connections:", #connections)
    for connectionIndex, connection in ipairs(connections) do
        local fn = connection.Function or connection.FunctionRef
        if type(fn) ~= "function" then
            Log("Connection", connectionIndex, "has no function")
            continue
        end

        local infoOk, info = pcall(getinfo, fn)
        if not infoOk or not info then
            Log("Connection", connectionIndex, "getinfo failed")
            continue
        end

        Log("Connection", connectionIndex, "source=", info.source or info.short_src,
            "name=", info.name, "line=", info.linedefined, "nups=", info.nups)

        for upIndex = 1, (info.nups or 0) do
            local upOk, upName, value = pcall(getupvalue, fn, upIndex)
            if upOk and upName ~= nil then
                Log("  Upvalue", upIndex, upName, Describe(value))
                if IsDragClass(value) then
                    found[#found + 1] = {
                        signal = signalName,
                        connection = connectionIndex,
                        upvalue = upIndex,
                        class = value
                    }
                    Log("  >>> NATIVE DRAG CLASS FOUND <<<")
                elseif type(value) == "table" then
                    for nestedKey, nestedValue in pairs(value) do
                        if IsDragClass(nestedValue) then
                            found[#found + 1] = {
                                signal = signalName,
                                connection = connectionIndex,
                                upvalue = upIndex,
                                nested = nestedKey,
                                class = nestedValue
                            }
                            Log("  >>> NESTED DRAG CLASS FOUND:", tostring(nestedKey), "<<<")
                        end
                    end
                end
            end
        end
    end
end

local unique = {}
for _, entry in ipairs(found) do
    if not unique[entry.class] then
        unique[entry.class] = true
        Log("========== FOUND CLASS METHODS ==========")
        Log("Location:", entry.signal, "connection", entry.connection, "upvalue", entry.upvalue,
            "nested", tostring(entry.nested))
        for _, methodName in ipairs({"new", "Drag", "Reset"}) do
            local fn = entry.class[methodName]
            local ok, info = pcall(getinfo, fn)
            Log("METHOD", methodName, "function=", tostring(fn),
                "source=", ok and (info.source or info.short_src) or "?",
                "line=", ok and info.linedefined or "?",
                "nups=", ok and info.nups or "?")
            for index = 1, (ok and info.nups or 0) do
                local upOk, name, value = pcall(getupvalue, fn, index)
                if upOk and name ~= nil then
                    Log("  ", methodName, "upvalue", index, name, Describe(value))
                end
            end
            if type(getconstants) == "function" then
                local cOk, constants = pcall(getconstants, fn)
                if cOk and type(constants) == "table" then
                    for index, value in ipairs(constants) do
                        Log("  ", methodName, "constant", index, tostring(value))
                    end
                end
            end
        end
    end
end

if #found == 0 then
    Log("No Drag class table found in direct or one-level nested signal upvalues.")
    Log("The earlier Drag table may be captured by an intermediate closure; next pass should inspect callback upvalue functions.")
end

Log("========== END; READ-ONLY ==========")
