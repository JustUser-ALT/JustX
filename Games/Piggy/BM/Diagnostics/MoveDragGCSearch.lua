--==================================================
-- MOVE DRAG GC SEARCH
-- Searches Lua GC objects for the native Drag class.
-- Read-only: does not invoke Drag methods or mutate state.
--==================================================

local function Log(...) print("[MoveDragGCSearch]", ...) end

local getinfo = (type(debug) == "table" and debug.getinfo) or getinfo
local getupvalue = (type(debug) == "table" and debug.getupvalue) or getupvalue
local getconstants = (type(debug) == "table" and debug.getconstants) or getconstants

assert(type(getgc) == "function", "getgc unavailable")
assert(type(getinfo) == "function", "debug.getinfo unavailable")

local function IsFunction(value)
    return type(value) == "function"
end

local function IsDragClass(value)
    return type(value) == "table"
        and IsFunction(rawget(value, "new"))
        and IsFunction(rawget(value, "Drag"))
        and IsFunction(rawget(value, "Reset"))
end

local function DescribeFunction(label, fn)
    Log("----------", label, "----------")
    local ok, info = pcall(getinfo, fn)
    if ok and info then
        Log("Function:", tostring(fn))
        Log("Source:", info.source or info.short_src)
        Log("Name:", info.name)
        Log("Line:", info.linedefined, "-", info.lastlinedefined)
        Log("Nups:", info.nups)
    else
        Log("getinfo failed:", info)
    end

    if type(getupvalue) == "function" and ok and info then
        for index = 1, info.nups or 0 do
            local packed = table.pack(pcall(getupvalue, fn, index))
            if packed[1] then
                Log("Upvalue raw return", index, "count=", packed.n - 1)
                for resultIndex = 2, packed.n do
                    local value = packed[resultIndex]
                    Log("  return", resultIndex - 1, "type=", typeof(value), "value=", tostring(value))
                end
            end
        end
    end

    if type(getconstants) == "function" then
        local cOk, constants = pcall(getconstants, fn)
        if cOk and type(constants) == "table" then
            for index, value in ipairs(constants) do
                Log("Constant", index, "=", tostring(value))
            end
        end
    end
end

Log("Scanning getgc(true)...")
local objects = getgc(true)
Log("GC object count:", #objects)

local matches = {}
local seen = {}

for index, object in ipairs(objects) do
    if IsDragClass(object) and not seen[object] then
        seen[object] = true
        matches[#matches + 1] = {index = index, class = object}
    end
end

Log("Exact Drag class table matches:", #matches)

for matchIndex, entry in ipairs(matches) do
    local class = entry.class
    Log("========== CLASS MATCH", matchIndex, "GC INDEX", entry.index, "==========")
    for _, methodName in ipairs({"new", "Drag", "Reset"}) do
        DescribeFunction("Drag." .. methodName, rawget(class, methodName))
    end
end

-- Also inspect BuildModeClient callbacks' raw getupvalue return values.
local Players = game:GetService("Players")
local BuildModeGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local ClientState

for _, object in ipairs(objects) do
    if type(object) == "table"
        and rawget(object, "ScreenGui") == BuildModeGui
        and rawget(object, "Toolbar") then
        ClientState = object
        break
    end
end

if ClientState and type(getconnections) == "function" then
    for _, signalName in ipairs({"MouseDrag", "MouseButton1Down", "MouseButton1Up"}) do
        local signal = ClientState.MoveHandles and ClientState.MoveHandles[signalName]
        if signal then
            local ok, connections = pcall(getconnections, signal)
            if ok and type(connections) == "table" then
                Log("========== RAW CALLBACK UPS VALUES:", signalName, "==========")
                for connectionIndex, connection in ipairs(connections) do
                    local fn = connection.Function or connection.FunctionRef
                    if IsFunction(fn) then
                        local infoOk, info = pcall(getinfo, fn)
                        Log("Connection", connectionIndex, "source=", infoOk and info and info.source,
                            "nups=", infoOk and info and info.nups)
                        if infoOk and info then
                            for upIndex = 1, info.nups or 0 do
                                local packed = table.pack(pcall(getupvalue, fn, upIndex))
                                if packed[1] then
                                    Log("  index", upIndex, "raw count=", packed.n - 1)
                                    for resultIndex = 2, packed.n do
                                        local value = packed[resultIndex]
                                        Log("    return", resultIndex - 1, "type=", typeof(value),
                                            "value=", type(value) == "table" and tostring(value) or tostring(value))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
else
    Log("ClientState or getconnections unavailable for callback cross-check")
end

Log("========== END; READ-ONLY ==========")
