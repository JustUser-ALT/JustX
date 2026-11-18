--==================================================
-- MOVE INTERNAL STATE DIAGNOSTIC
-- Read-only inspection of native MouseDrag closure state.
-- Does not change callbacks, constants, or models.
--==================================================

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local function log(...) print("[MoveInternalState]", ...) end

local player = Players.LocalPlayer
player:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")

local BMC = require(RS:WaitForChild("BuildMode"):WaitForChild("BuildModeClient"))
local classUpvalues = debug.getupvalues(BMC.new)
local class = classUpvalues and classUpvalues[3]
assert(class, "BuildModeClient class not found")

local clientState
for _, object in ipairs(getgc(true)) do
    if type(object) == "table" and getmetatable(object) == class
        and type(rawget(object, "MoveHandles")) == "table" then
        clientState = object
        break
    end
end
assert(clientState, "Live ClientState with MoveHandles not found")

local handles = clientState.MoveHandles
local ok, connections = pcall(getconnections, handles.MouseDrag)
assert(ok and type(connections) == "table", "MouseDrag connections unavailable")

local function describe(value)
    local kind = typeof(value)
    if kind == "Instance" then
        local success, name = pcall(function() return value:GetFullName() end)
        return success and name or tostring(value)
    elseif kind == "Vector3" then
        return string.format("Vector3(%.4f, %.4f, %.4f)", value.X, value.Y, value.Z)
    elseif kind == "CFrame" then
        local p = value.Position
        return string.format("CFrame(%.4f, %.4f, %.4f)", p.X, p.Y, p.Z)
    end
    return tostring(value) .. " [" .. kind .. "]"
end

local function dumpTable(label, value, depth, seen)
    if type(value) ~= "table" then
        log(label, describe(value))
        return
    end
    if seen[value] then
        log(label, "already visited")
        return
    end
    seen[value] = true

    log("TABLE", label, "depth", depth)
    local count = 0
    for key, item in pairs(value) do
        count = count + 1
        log(label .. "." .. tostring(key), describe(item))
        if type(item) == "table" and depth < 2 then
            dumpTable(label .. "." .. tostring(key), item, depth + 1, seen)
        end
        if count >= 80 then
            log(label, "truncated at 80 keys")
            break
        end
    end
    log(label, "key count sampled", count)
end

for index, connection in ipairs(connections) do
    local fn = connection.Function
    if type(fn) == "function" then
        log("===== CALLBACK", index, "=====")

        local constants = {}
        if debug.getconstants then
            local success, values = pcall(debug.getconstants, fn)
            if success and type(values) == "table" then constants = values end
        end
        for i, value in ipairs(constants) do
            log("CONSTANT", i, describe(value))
        end

        local success, upvalues = pcall(debug.getupvalues, fn)
        if success and type(upvalues) == "table" then
            for i, value in pairs(upvalues) do
                log("UPVALUE", i, describe(value))
                if type(value) == "table" then
                    dumpTable("U" .. tostring(i), value, 0, {})
                end
            end
        else
            log("Could not enumerate callback upvalues", tostring(upvalues))
        end
    end
end

log("===== HANDLE INTERNALS =====")
dumpTable("MoveHandles", handles, 0, {})

local functions = RS:FindFirstChild("Functions")
local commit = functions and functions:FindFirstChild("CommitMove")
log("CommitMove remote:", commit and commit.ClassName or "missing")
log("SelectedBlock:", describe(clientState.SelectedBlock))

log("===== END: read-only diagnostic =====")
