--==================================================
-- MOVE DRAG SOURCE DIAGNOSTIC
-- Reads decompiled source for the native Move handle callbacks.
-- Also inspects the shared callback state table keys.
-- No callbacks, constants, or block transforms are modified.
--==================================================

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local function log(...)
    print("[MoveDragSource]", ...)
end

local function dumpSource(label, fn)
    log("===== SOURCE:", label, "=====")

    if type(fn) ~= "function" then
        log("Function unavailable")
        return
    end

    if type(decompile) ~= "function" then
        log("decompile unavailable")
        return
    end

    local ok, source = pcall(decompile, fn)
    if not ok or type(source) ~= "string" then
        log("Decompile failed:", tostring(source))
        return
    end

    local lines = {}
    for line in string.gmatch(source, "([^\n]+)") do
        lines[#lines + 1] = line
    end

    log("Source lines:", #lines)
    for index, line in ipairs(lines) do
        log("L" .. index, string.sub(line, 1, 350))
        if index >= 100 then
            log("Source truncated at 100 lines")
            break
        end
    end
end

local function inspectStateTable(fn, label)
    if type(debug) ~= "table" or type(debug.getupvalue) ~= "function" then
        log(label, "debug.getupvalue unavailable")
        return
    end

    local ok, name, state = pcall(debug.getupvalue, fn, 1)
    if not ok or type(state) ~= "table" then
        log(label, "shared state table unavailable")
        return
    end

    log("===== SHARED STATE:", label, "=====")
    local count = 0
    for key, value in pairs(state) do
        count = count + 1
        local valueType = typeof(value)
        local description = tostring(value)

        if valueType == "Instance" then
            description = value:GetFullName()
        elseif type(value) == "table" then
            local nestedCount = 0
            for _ in pairs(value) do
                nestedCount = nestedCount + 1
                if nestedCount >= 12 then break end
            end
            description = "table (sample count " .. tostring(nestedCount) .. ")"
        end

        log("STATE", tostring(key), valueType, description)
        if count >= 100 then
            log("State keys truncated at 100")
            break
        end
    end
    log("State key count:", count, "upvalue name:", tostring(name))
end

local function findMoveHandles()
    local module = require(RS:WaitForChild("BuildMode"):WaitForChild("BuildModeClient"))
    local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")

    if type(getgc) ~= "function" or type(debug) ~= "table"
        or type(debug.getupvalues) ~= "function" then
        return nil, "getgc or debug.getupvalues unavailable"
    end

    local ok, upvalues = pcall(debug.getupvalues, module.new)
    if not ok or type(upvalues) ~= "table" then
        return nil, "Could not inspect BuildModeClient.new upvalues"
    end

    local class = upvalues[3]
    if not class then
        return nil, "BuildModeClient class upvalue not found"
    end

    for _, object in ipairs(getgc(true)) do
        if type(object) == "table" and getmetatable(object) == class then
            local handles = rawget(object, "MoveHandles")
            if handles then
                return handles
            end
        end
    end

    return nil, "Live MoveHandles not found"
end

local handles, reason = findMoveHandles()
if not handles then
    log(reason)
    return
end

log("MoveHandles found")

if type(getconnections) ~= "function" then
    log("getconnections unavailable")
    return
end

for _, signalName in ipairs({"MouseDrag", "MouseButton1Down", "MouseButton1Up"}) do
    local ok, signal = pcall(function()
        return handles[signalName]
    end)

    if ok and signal then
        local success, connections = pcall(getconnections, signal)
        if success and type(connections) == "table" then
            for index, connection in ipairs(connections) do
                local fn = connection.Function
                local label = signalName .. " #" .. index
                dumpSource(label, fn)
                inspectStateTable(fn, label)
            end
        else
            log("Could not read connections:", signalName)
        end
    end
end

log("===== END: read-only diagnostic =====")
