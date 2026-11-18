--==================================================
-- MOVE DRAG HANDLER DIAGNOSTIC
-- Inspects callbacks connected to the native MoveHandles
-- signals without changing BuildMode state or behavior.
--==================================================

local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")

local function Log(...)
    print("[MoveDragHandlerDiagnostic]", ...)
end

local function SafePath(value)
    if typeof(value) == "Instance" then
        local ok, path = pcall(function()
            return value:GetFullName()
        end)
        return ok and path or tostring(value)
    end
    return tostring(value)
end

local function GetDebugFunction(name)
    if type(debug) == "table" and type(debug[name]) == "function" then
        return debug[name]
    end
    local globalFunction = getgenv and getgenv()[name]
    if type(globalFunction) == "function" then
        return globalFunction
    end
    return nil
end

local getInfo = GetDebugFunction("getinfo")
local getUpvalues = GetDebugFunction("getupvalues")
local getConstants = GetDebugFunction("getconstants")

local ClientState
assert(type(getgc) == "function", "[MoveDragHandlerDiagnostic] getgc unavailable")

for attempt = 1, 100 do
    for _, object in ipairs(getgc(true)) do
        if type(object) == "table"
            and rawget(object, "ScreenGui") == BuildModeGui
            and rawget(object, "Toolbar")
            and rawget(object, "MoveHandles") then
            ClientState = object
            break
        end
    end
    if ClientState then break end
    task.wait(0.1)
end

assert(ClientState, "[MoveDragHandlerDiagnostic] BuildModeClient state not found")

local MoveHandles = ClientState.MoveHandles
Log("ClientState found:", tostring(ClientState))
Log("SelectedBlock:", SafePath(ClientState.SelectedBlock))
Log("MoveHandles._Adornee:", SafePath(rawget(MoveHandles, "_Adornee")))
Log("MoveHandles type:", typeof(MoveHandles))

local function InspectSignal(signalName)
    local signal = MoveHandles[signalName]
    Log("========== SIGNAL:", signalName, "==========")

    if type(getconnections) ~= "function" then
        Log("getconnections unavailable")
        return
    end

    local ok, connections = pcall(getconnections, signal)
    if not ok then
        Log("getconnections failed:", tostring(connections))
        return
    end

    Log("Connection count:", #connections)

    for index, connection in ipairs(connections) do
        local callback = connection.Function
        Log("-- Connection", index, "--")
        Log("Enabled:", tostring(connection.Enabled))
        Log("Function:", tostring(callback))

        if type(callback) ~= "function" then
            Log("No inspectable Function")
            continue
        end

        if getInfo then
            local infoOk, info = pcall(getInfo, callback)
            if infoOk and type(info) == "table" then
                Log("Source:", tostring(info.source or info.short_src))
                Log("Name:", tostring(info.name))
                Log("Line:", tostring(info.currentline or info.linedefined))
                Log("What:", tostring(info.what))
                Log("Nups:", tostring(info.nups))
            else
                Log("getinfo failed:", tostring(info))
            end
        end

        if getUpvalues then
            local upOk, upvalues = pcall(getUpvalues, callback)
            if upOk and type(upvalues) == "table" then
                for key, value in pairs(upvalues) do
                    local valueType = typeof(value)
                    local rendered = SafePath(value)

                    if type(value) == "table" then
                        local keys = {}
                        local count = 0
                        for childKey in pairs(value) do
                            count += 1
                            if count <= 12 then
                                table.insert(keys, tostring(childKey))
                            end
                        end
                        rendered = "table keys={" .. table.concat(keys, ", ") .. "}"
                    elseif type(value) == "function" then
                        rendered = "function " .. tostring(value)
                    end

                    Log("Upvalue", tostring(key), "type=", valueType, "value=", rendered)
                end
            else
                Log("getupvalues failed/unavailable:", tostring(upvalues))
            end
        else
            Log("getupvalues unavailable")
        end

        if getConstants then
            local constOk, constants = pcall(getConstants, callback)
            if constOk and type(constants) == "table" then
                for key, value in pairs(constants) do
                    if type(value) == "string" then
                        Log("Constant", tostring(key), "=", value)
                    end
                end
            else
                Log("getconstants failed/unavailable:", tostring(constants))
            end
        else
            Log("getconstants unavailable")
        end
    end
end

InspectSignal("MouseButton1Down")
InspectSignal("MouseDrag")
InspectSignal("MouseButton1Up")

Log("========== END ==========")
Log("No BuildMode values, handles, or connections were modified.")
