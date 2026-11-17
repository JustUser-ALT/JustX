-- Native Move Tool State Diagnostic
-- Run in the ORIGINAL Piggy Build Mode. Read-only; does not change selection or handles.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")
local BMC = require(RS:WaitForChild("BuildMode"):WaitForChild("BuildModeClient"))

local function Describe(value)
    local kind = typeof(value)
    if kind == "Instance" then
        return value:GetFullName() .. " <" .. value.ClassName .. ">"
    elseif kind == "table" then
        local mt = getmetatable(value)
        return "table" .. (mt and " [metatable]" or "")
    elseif kind == "function" then
        return "function"
    end
    return tostring(value) .. " <" .. kind .. ">"
end

local function DumpTable(label, object, depth)
    if type(object) ~= "table" then
        print("[MoveState] " .. label .. " = " .. Describe(object))
        return
    end

    depth = depth or 0
    local indent = string.rep("  ", depth)
    print("\n" .. indent .. "[MoveState] " .. label .. " (table)")

    local count = 0
    for key, value in pairs(object) do
        count += 1
        if count > 100 then
            print(indent .. "  ... truncated after 100 entries")
            break
        end

        local keyText = tostring(key)
        print(indent .. "  " .. keyText .. " = " .. Describe(value))

        if depth == 0 and type(value) == "table" then
            local nestedCount = 0
            for nestedKey, nestedValue in pairs(value) do
                nestedCount += 1
                if nestedCount > 30 then
                    print(indent .. "    ... nested table truncated")
                    break
                end
                print(indent .. "    ." .. tostring(nestedKey) .. " = " .. Describe(nestedValue))
            end
        end
    end
end

local function DumpFunction(label, fn)
    if type(fn) ~= "function" then return end
    print("\n[MoveState] Function: " .. label)

    if debug and debug.getconstants then
        local ok, constants = pcall(debug.getconstants, fn)
        if ok and type(constants) == "table" then
            for index, value in pairs(constants) do
                if type(value) ~= "string" or #value < 120 then
                    print("  constant[" .. tostring(index) .. "] = " .. Describe(value))
                end
            end
        end
    end

    if debug and debug.getupvalues then
        local ok, upvalues = pcall(debug.getupvalues, fn)
        if ok and type(upvalues) == "table" then
            for index, value in pairs(upvalues) do
                print("  upvalue[" .. tostring(index) .. "] = " .. Describe(value))
                if type(value) == "table" then
                    local count = 0
                    for key, nested in pairs(value) do
                        count += 1
                        if count > 20 then
                            print("    ... upvalue table truncated")
                            break
                        end
                        print("    ." .. tostring(key) .. " = " .. Describe(nested))
                    end
                end
            end
        end
    end
end

print("========== NATIVE MOVE STATE DIAGNOSTIC ==========")
print("[MoveState] BuildModeGui: " .. BuildModeGui:GetFullName())

local ok, upvalues = pcall(debug.getupvalues, BMC.new)
local class = ok and type(upvalues) == "table" and upvalues[3]
assert(class, "[MoveState] BuildModeClient class not found in BMC.new upvalue 3")
print("[MoveState] BuildModeClient class: " .. Describe(class))

local found = 0
for _, object in ipairs(getgc(true)) do
    if type(object) == "table" and getmetatable(object) == class then
        found += 1
        print("\n========== CLIENT STATE #" .. found .. " ==========")
        DumpTable("ClientState", object, 0)

        local handles = rawget(object, "MoveHandles")
        if handles then
            DumpTable("MoveHandles", handles, 0)
            for _, key in ipairs({"MouseDrag", "MouseButton1Down", "MouseButton1Up", "TouchMoved"}) do
                local value = handles[key]
                if type(value) == "function" then
                    DumpFunction("MoveHandles." .. key, value)
                end
            end
        end

        for key, value in pairs(object) do
            if type(value) == "function" then
                local keyName = tostring(key)
                if keyName:lower():find("select") or keyName:lower():find("move")
                    or keyName:lower():find("block") or keyName:lower():find("action") then
                    DumpFunction("ClientState." .. keyName, value)
                end
            end
        end
    end
end

print("\n[MoveState] ClientState instances found: " .. found)
print("========== END MOVE STATE DIAGNOSTIC ==========")
