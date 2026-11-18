--==================================================
-- MOVE DRAG DIAGNOSTIC
-- Read-only inspection of the native Build Mode Move drag handler.
-- Does not move blocks, change constants, or replace callbacks.
--==================================================

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local function log(...)
    print("[MoveDragDiagnostic]", ...)
end

local function safeName(value)
    if typeof(value) == "Instance" then
        return value:GetFullName()
    end
    return tostring(value)
end

local function getDebugFunction(name)
    local debugTable = debug
    return type(debugTable) == "table" and debugTable[name] or nil
end

local function dumpFunction(fn, label)
    log("----- FUNCTION:", label, "-----")

    if type(fn) ~= "function" then
        log("Not a function:", typeof(fn))
        return
    end

    local getinfo = getDebugFunction("getinfo")
    if type(getinfo) == "function" then
        local ok, info = pcall(getinfo, fn)
        if ok and type(info) == "table" then
            log("INFO", "name=" .. tostring(info.name),
                "source=" .. tostring(info.short_src or info.source),
                "line=" .. tostring(info.linedefined),
                "params=" .. tostring(info.nparams),
                "vararg=" .. tostring(info.is_vararg))
        end
    end

    local getconstants = getDebugFunction("getconstants")
    if type(getconstants) == "function" then
        local ok, constants = pcall(getconstants, fn)
        if ok and type(constants) == "table" then
            log("CONSTANTS count=" .. tostring(#constants))
            for index, value in ipairs(constants) do
                if index > 70 then
                    log("CONSTANTS truncated at 70")
                    break
                end
                log("C" .. index, typeof(value), safeName(value))
            end
        else
            log("CONSTANTS unavailable")
        end
    else
        log("debug.getconstants unavailable")
    end

    local getupvalue = getDebugFunction("getupvalue")
    if type(getupvalue) == "function" then
        log("UPVALUES")
        for index = 1, 30 do
            local ok, name, value = pcall(getupvalue, fn, index)
            if not ok or name == nil then
                break
            end

            local description = typeof(value)
            if description == "Instance" then
                description = description .. " " .. safeName(value)
            elseif type(value) == "table" then
                local count = 0
                for _ in pairs(value) do
                    count = count + 1
                    if count >= 20 then break end
                end
                description = description .. " (sample count " .. tostring(count) .. ")"
            elseif type(value) ~= "function" then
                description = description .. " " .. tostring(value)
            end

            log("U" .. index, tostring(name), description)
        end
    else
        log("debug.getupvalue unavailable")
    end
end

local BuildMode = RS:WaitForChild("BuildMode")
local BuildModeClientModule = require(BuildMode:WaitForChild("BuildModeClient"))
local BuildModeGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")

local ClientState
local MoveHandles

log("Searching live BuildModeClient...")

if type(getgc) == "function" then
    for _, object in ipairs(getgc(true)) do
        if type(object) == "table"
            and rawget(object, "ScreenGui") == BuildModeGui
            and rawget(object, "Toolbar") then
            ClientState = object
            break
        end
    end
else
    log("getgc unavailable")
end

if ClientState then
    log("ClientState found")
    MoveHandles = rawget(ClientState, "MoveHandles")
    log("SelectedBlock:", safeName(rawget(ClientState, "SelectedBlock")))
    log("MoveHandles:", safeName(MoveHandles))
else
    log("ClientState not found by ScreenGui + Toolbar signature")
end

if not MoveHandles then
    local getupvalues = getDebugFunction("getupvalues")
    if type(getupvalues) == "function" and type(BuildModeClientModule.new) == "function" then
        local ok, values = pcall(getupvalues, BuildModeClientModule.new)
        if ok and type(values) == "table" then
            local class = values[3]
            if class and type(getgc) == "function" then
                for _, object in ipairs(getgc(true)) do
                    if type(object) == "table" and getmetatable(object) == class then
                        if rawget(object, "MoveHandles") then
                            MoveHandles = rawget(object, "MoveHandles")
                            log("MoveHandles found through BuildModeClient class")
                            break
                        end
                    end
                end
            end
        end
    end
end

if not MoveHandles then
    log("MoveHandles not found; diagnostic cannot inspect drag signal")
    return
end

local function inspectSignal(signalName)
    local ok, signal = pcall(function()
        return MoveHandles[signalName]
    end)

    if not ok or signal == nil then
        return
    end

    log("SIGNAL", signalName, typeof(signal))

    if type(getconnections) ~= "function" then
        log("getconnections unavailable")
        return
    end

    local success, connections = pcall(getconnections, signal)
    if not success or type(connections) ~= "table" then
        log("Could not read connections for", signalName)
        return
    end

    log(signalName .. " connection count=" .. tostring(#connections))

    for index, connection in ipairs(connections) do
        local fn = connection.Function
        log("CONNECTION", signalName, index,
            "enabled=" .. tostring(connection.Enabled),
            "function=" .. tostring(fn))

        if type(fn) == "function" then
            dumpFunction(fn, signalName .. " connection " .. index)
        end
    end
end

inspectSignal("MouseDrag")
inspectSignal("MouseButton1Down")
inspectSignal("MouseButton1Up")

log("===== END: no state was modified =====")
