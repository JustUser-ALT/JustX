-- ResizeInternalsProbe.lua
-- Read-only inspection of native Piggy Resize internals.
-- Run while one block is selected in the native Resize mode.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")
local BMC = require(RS.BuildMode.BuildModeClient)
local class = debug.getupvalues(BMC.new)[3]

local function log(...)
    print("[ResizeInternalsProbe]", ...)
end

local function safeGetUpvalues(fn)
    local ok, values = pcall(debug.getupvalues, fn)
    return ok and values or {}
end

local function safeGetConstants(fn)
    local ok, values = pcall(debug.getconstants, fn)
    return ok and values or {}
end

local function dumpTable(value, label, depth, seen)
    depth = depth or 0
    seen = seen or {}
    local indent = string.rep("  ", depth)

    if type(value) ~= "table" then
        log(indent .. label .. " = " .. tostring(value) .. " [" .. typeof(value) .. "]")
        return
    end

    if seen[value] then
        log(indent .. label .. " = <already visited>")
        return
    end
    seen[value] = true

    log(indent .. label .. " = table")
    if depth >= 3 then
        return
    end

    local count = 0
    for key, item in pairs(value) do
        count += 1
        if count > 60 then
            log(indent .. "  ... truncated")
            break
        end

        if type(item) == "function" then
            log(indent .. "  [" .. tostring(key) .. "] function " .. tostring(item))
            local constants = safeGetConstants(item)
            for index, constant in pairs(constants) do
                log(indent .. "    constant[" .. tostring(index) .. "] = " .. tostring(constant))
            end
            local ups = safeGetUpvalues(item)
            for index, upvalue in pairs(ups) do
                if type(upvalue) == "table" then
                    local keys = {}
                    for k in pairs(upvalue) do
                        table.insert(keys, tostring(k))
                        if #keys >= 20 then break end
                    end
                    log(indent .. "    upvalue[" .. tostring(index) .. "] table keys={" .. table.concat(keys, ", ") .. "}")
                else
                    log(indent .. "    upvalue[" .. tostring(index) .. "] = " .. tostring(upvalue) .. " [" .. typeof(upvalue) .. "]")
                end
            end
        elseif type(item) == "table" then
            dumpTable(item, "[" .. tostring(key) .. "]", depth + 1, seen)
        else
            log(indent .. "  [" .. tostring(key) .. "] = " .. tostring(item) .. " [" .. typeof(item) .. "]")
        end
    end
end

local ClientState
for attempt = 1, 100 do
    for _, object in ipairs(getgc(true)) do
        if type(object) == "table"
            and getmetatable(object) == class
            and rawget(object, "ScreenGui") == BuildModeGui
            and rawget(object, "ResizeHandles") then
            ClientState = object
            break
        end
    end
    if ClientState then break end
    task.wait(0.1)
end

if not ClientState then
    warn("[ResizeInternalsProbe] BuildMode ClientState not found")
    return
end

local handles = ClientState.ResizeHandles
log("SelectedBlock =", ClientState.SelectedBlock)
log("Handles Adornee =", handles._Adornee)
log("Handles metatable:")
dumpTable(getmetatable(handles), "ResizeHandles metatable", 0)

for _, signalName in ipairs({"MouseButton1Down", "MouseDrag", "MouseButton1Up"}) do
    local signal = handles[signalName]
    log("SIGNAL", signalName, signal)

    local ok, connections = pcall(getconnections, signal)
    if not ok or not connections then
        log("  getconnections failed")
        continue
    end

    for connectionIndex, connection in ipairs(connections) do
        local fn = connection.Function
        if type(fn) == "function" then
            log("  CONNECTION", connectionIndex, "enabled=", connection.Enabled, "function=", fn)

            for constantIndex, constant in pairs(safeGetConstants(fn)) do
                log("    constant[" .. tostring(constantIndex) .. "] =", constant)
            end

            for upvalueIndex, upvalue in pairs(safeGetUpvalues(fn)) do
                if type(upvalue) == "table" then
                    dumpTable(upvalue, "upvalue[" .. tostring(upvalueIndex) .. "]", 1)
                else
                    log("    upvalue[" .. tostring(upvalueIndex) .. "] =", upvalue, "[" .. typeof(upvalue) .. "]")
                end
            end
        end
    end
end

log("Selected model parts:")
local selected = ClientState.SelectedBlock
if selected then
    for _, descendant in ipairs(selected:GetDescendants()) do
        if descendant:IsA("BasePart") then
            log(descendant:GetFullName(), "Size=", descendant.Size, "CFrame=", descendant.CFrame)
        end
    end
end

log("===== END =====")
