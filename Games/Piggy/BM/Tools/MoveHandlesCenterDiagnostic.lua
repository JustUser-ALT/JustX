--==================================================
-- MOVE HANDLES CENTER DIAGNOSTIC
-- Read-only inspection of native MoveHandles.
-- Run while BuildMode is active and MultiMoveTest is loaded.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")
local BuildModeFolder = RS:WaitForChild("BuildMode")

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
assert(typeof(Handles) == "Instance", "[MoveHandlesCenterDiagnostic] MoveHandles is not an Instance")

local function ReadProperty(object, property)
    local ok, value = pcall(function()
        return object[property]
    end)
    if ok then
        if typeof(value) == "Instance" then
            return value:GetFullName() .. " [" .. value.ClassName .. "]"
        end
        return tostring(value)
    end
    return "<unavailable>"
end

print("========== MOVE HANDLES INSPECTION ==========")
print("Class:", Handles.ClassName)
print("FullName:", Handles:GetFullName())
print("Parent:", ReadProperty(Handles, "Parent"))
print("Adornee:", ReadProperty(Handles, "Adornee"))
print("Visible:", ReadProperty(Handles, "Visible"))
print("Enabled:", ReadProperty(Handles, "Enabled"))
print("Style:", ReadProperty(Handles, "Style"))
print("Faces:", ReadProperty(Handles, "Faces"))
print("Color3:", ReadProperty(Handles, "Color3"))
print("Transparency:", ReadProperty(Handles, "Transparency"))
print("SelectedBlock:", ReadProperty(ClientState, "SelectedBlock"))
print("SelectedBlock Pivot:", (function()
    local block = ClientState.SelectedBlock
    if typeof(block) == "Instance" and block:IsA("Model") then
        local ok, pivot = pcall(function() return block:GetPivot() end)
        if ok then return tostring(pivot) end
    end
    return "<none>"
end)())

print("----- HANDLE CHILDREN -----")
for _, child in ipairs(Handles:GetChildren()) do
    print(child.ClassName, child.Name, child:GetFullName())
end

print("----- CLIENT STATE HANDLE-RELATED FIELDS -----")
for key, value in pairs(ClientState) do
    if type(key) == "string" and string.find(string.lower(key), "handle") then
        print(key, typeof(value), tostring(value))
    end
end

print("----- MOUSE DRAG CONNECTIONS -----")
local ok, connections = pcall(getconnections, Handles.MouseDrag)
if ok and type(connections) == "table" then
    for index, connection in ipairs(connections) do
        local fn = connection.Function or connection.Callback
        print("Connection", index, "Enabled:", tostring(connection.Enabled), "Function:", tostring(fn))
        if type(fn) == "function" and type(debug) == "table" then
            local constantsOk, constants = pcall(debug.getconstants, fn)
            if constantsOk and type(constants) == "table" then
                print("Constants:", table.concat((function()
                    local values = {}
                    for _, value in ipairs(constants) do
                        values[#values + 1] = tostring(value)
                    end
                    return values
                end)(), " | "))
            end
            local upvaluesOk, upvalues = pcall(debug.getupvalues, fn)
            if upvaluesOk and type(upvalues) == "table" then
                for upIndex, upvalue in pairs(upvalues) do
                    if typeof(upvalue) == "Instance" then
                        print("Upvalue", upIndex, upvalue.ClassName, upvalue:GetFullName())
                    elseif type(upvalue) == "table" then
                        print("Upvalue", upIndex, "table")
                        for field, fieldValue in pairs(upvalue) do
                            if type(field) == "string" and string.find(string.lower(field), "handle") then
                                print("  ", field, typeof(fieldValue), tostring(fieldValue))
                            end
                        end
                    else
                        print("Upvalue", upIndex, typeof(upvalue), tostring(upvalue))
                    end
                end
            end
        end
    end
else
    print("getconnections unavailable or no connections")
end

print("========== END DIAGNOSTIC ==========")
