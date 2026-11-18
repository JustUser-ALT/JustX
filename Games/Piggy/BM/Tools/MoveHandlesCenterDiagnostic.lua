--==================================================
-- MOVE HANDLES CENTER DIAGNOSTIC
-- Read-only inspection of native handle internals.
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
assert(type(Handles) == "table", "[MoveHandlesCenterDiagnostic] MoveHandles table not found")

local function Describe(label, value)
    if typeof(value) == "Instance" then
        print(label, "Instance", value.ClassName, value:GetFullName())
        local properties = {"Adornee", "CFrame", "Size", "Visible", "Transparency", "Color3", "AlwaysOnTop", "ZIndex", "Parent"}
        for _, property in ipairs(properties) do
            local ok, propertyValue = pcall(function() return value[property] end)
            if ok then
                if typeof(propertyValue) == "Instance" then
                    print("  ", property, propertyValue.ClassName, propertyValue:GetFullName())
                else
                    print("  ", property, tostring(propertyValue))
                end
            end
        end
    else
        print(label, typeof(value), tostring(value))
    end
end

local function InspectFunction(label, fn)
    if type(fn) ~= "function" then return end
    print("----- FUNCTION " .. label .. " -----")
    if type(debug) ~= "table" then return end
    local ok, constants = pcall(debug.getconstants, fn)
    if ok and type(constants) == "table" then
        local values = {}
        for _, value in ipairs(constants) do values[#values + 1] = tostring(value) end
        print("CONSTANTS", table.concat(values, " | "))
    end
    local upOk, upvalues = pcall(debug.getupvalues, fn)
    if upOk and type(upvalues) == "table" then
        for index, value in pairs(upvalues) do
            Describe("UPVALUE " .. tostring(index), value)
            if type(value) == "table" then
                for key, nested in pairs(value) do
                    Describe("  FIELD " .. tostring(key), nested)
                end
            end
        end
    end
end

print("========== MOVE HANDLES INTERNALS ==========")
print("HANDLE OBJECT", tostring(Handles))
for key, value in pairs(Handles) do
    if key ~= "_Handles" and key ~= "_Connections" then
        Describe("FIELD " .. tostring(key), value)
    end
end

local mt = getmetatable(Handles)
if type(mt) == "table" then
    InspectFunction("SetAdornee", mt.SetAdornee)
    InspectFunction("Destroy", mt.Destroy)
    InspectFunction("new", mt.new)
end

print("----- INTERNAL _HANDLES TABLE -----")
local internal = Handles._Handles
if type(internal) == "table" then
    for key, value in pairs(internal) do
        Describe("HANDLE ENTRY " .. tostring(key), value)
        if type(value) == "table" then
            for subKey, subValue in pairs(value) do
                Describe("  HANDLE FIELD " .. tostring(subKey), subValue)
            end
        end
    end
else
    print("_Handles is not a table:", typeof(internal))
end

print("----- ADORNMENT FOLDER CHILDREN -----")
local folder = Handles._Instance
if typeof(folder) == "Instance" then
    for _, child in ipairs(folder:GetChildren()) do
        Describe("CHILD", child)
    end
end

print("----- SELECTED BLOCK / PIVOT -----")
local selected = ClientState.SelectedBlock
Describe("SelectedBlock", selected)
if typeof(selected) == "Instance" and selected:IsA("Model") then
    print("Pivot", tostring(selected:GetPivot()))
    print("BoundingBox", tostring(selected:GetBoundingBox()))
end

print("========== END DIAGNOSTIC ==========")

--==================================================
-- RENDER / ADORNEE UPDATE PATH
--==================================================

print("========== RENDER PIPELINE INSPECTION ==========")

local classTable
local destroyMethod = mt and mt.Destroy
if type(destroyMethod) == "function" and type(debug) == "table" then
    local ok, values = pcall(debug.getupvalues, destroyMethod)
    if ok and type(values) == "table" then
        for _, value in pairs(values) do
            if type(value) == "table"
                and type(rawget(value, "Render")) == "function"
                and type(rawget(value, "_AdorneeChanged")) == "function" then
                classTable = value
                break
            end
        end
    end
end

if classTable then
    print("HANDLE CLASS TABLE FOUND")
    InspectFunction("CLASS Render", classTable.Render)
    InspectFunction("CLASS _AdorneeChanged", classTable._AdorneeChanged)
    InspectFunction("CLASS SetAdornee", classTable.SetAdornee)
else
    print("HANDLE CLASS TABLE NOT FOUND")
end

InspectFunction("INSTANCE SetAdornee", mt and mt.SetAdornee)

print("========== END RENDER PIPELINE ==========")

