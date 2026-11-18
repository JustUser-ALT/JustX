--==================================================
-- MOVE HANDLES CENTER DIAGNOSTIC
-- Read-only inspection. Supports table/userdata handles.
-- Run while BuildMode is active and MultiMoveTest is loaded.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")

local ClientState
assert(type(getgc) == "function", "[MoveHandlesCenterDiagnostic] getgc unavailable")

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

assert(ClientState, "[MoveHandlesCenterDiagnostic] BuildModeClient not found")

local Handles = ClientState.MoveHandles
print("========== MOVE HANDLES INSPECTION ==========")
print("MoveHandles type:", type(Handles))
print("MoveHandles typeof:", typeof(Handles))
print("MoveHandles tostring:", tostring(Handles))
print("SelectedBlock:", tostring(ClientState.SelectedBlock))

local function Describe(label, value)
    local kind = typeof(value)
    if kind == "Instance" then
        print(label, "Instance", value.ClassName, value:GetFullName())
    elseif type(value) == "function" then
        print(label, "function", tostring(value))
    elseif type(value) == "table" then
        print(label, "table", tostring(value))
    else
        print(label, kind, tostring(value))
    end
end

local function InspectTable(label, object)
    if type(object) ~= "table" then return end
    print("----- " .. label .. " FIELDS -----")
    for key, value in pairs(object) do
        Describe("FIELD " .. tostring(key), value)
    end
end

InspectTable("MOVE HANDLES", Handles)

local mt
if type(Handles) == "table" then
    local ok, result = pcall(getmetatable, Handles)
    if ok then mt = result end
elseif type(Handles) == "userdata" then
    local ok, result = pcall(getmetatable, Handles)
    if ok then mt = result end
end

if type(mt) == "table" then
    InspectTable("MOVE HANDLES METATABLE", mt)
    if type(mt.__index) == "table" then
        InspectTable("MOVE HANDLES __INDEX", mt.__index)
    end
end

print("----- CLIENT STATE HANDLE-RELATED FIELDS -----")
for key, value in pairs(ClientState) do
    if type(key) == "string" and string.find(string.lower(key), "handle") then
        Describe("CLIENT " .. key, value)
    end
end

print("----- HANDLE SIGNAL CONNECTIONS -----")
if type(Handles) == "table" then
    for _, signalName in ipairs({"MouseButton1Down", "MouseDrag", "MouseButton1Up"}) do
        local signal = Handles[signalName]
        Describe("SIGNAL " .. signalName, signal)
        if signal and type(getconnections) == "function" then
            local ok, connections = pcall(getconnections, signal)
            if ok and type(connections) == "table" then
                for index, connection in ipairs(connections) do
                    local fn = connection.Function or connection.Callback
                    print("CONNECTION", signalName, index, "Enabled:", tostring(connection.Enabled), "Function:", tostring(fn))
                    if type(fn) == "function" and type(debug) == "table" then
                        local constantsOk, constants = pcall(debug.getconstants, fn)
                        if constantsOk and type(constants) == "table" then
                            local values = {}
                            for _, value in ipairs(constants) do
                                values[#values + 1] = tostring(value)
                            end
                            print("CONSTANTS", signalName, index, table.concat(values, " | "))
                        end
                        local upvaluesOk, upvalues = pcall(debug.getupvalues, fn)
                        if upvaluesOk and type(upvalues) == "table" then
                            for upIndex, upvalue in pairs(upvalues) do
                                if type(upvalue) == "table" then
                                    print("UPVALUE", signalName, index, upIndex, "table", tostring(upvalue))
                                    for field, fieldValue in pairs(upvalue) do
                                        if type(field) == "string" then
                                            Describe("  UPVALUE FIELD " .. field, fieldValue)
                                        end
                                    end
                                else
                                    Describe("UPVALUE " .. signalName .. " " .. index .. " " .. upIndex, upvalue)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
else
    print("MoveHandles is not a table; signal field inspection skipped.")
end

print("========== END DIAGNOSTIC ==========")
