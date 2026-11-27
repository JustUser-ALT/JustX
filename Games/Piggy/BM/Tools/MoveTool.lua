local Env = (getgenv and getgenv()) or _G
local RS = game:GetService("ReplicatedStorage")
local BMC = require(RS.BuildMode.BuildModeClient)

local class = debug.getupvalues(BMC.new)[3]
assert(class, "BuildModeClient class not found")

local Steps = type(Env.JustXPiggyToolSteps) == "table" and Env.JustXPiggyToolSteps or {}
Env.JustXPiggyToolSteps = Steps
local step = tonumber(Steps.Move) or 0.1
Steps.Move = step

local GridDividerFactory = Env.JustXPiggyGridDividerFactory
if type(GridDividerFactory) ~= "function" then
    local source = game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustX/main/Games/Piggy/BM/Tools/GridDivider.lua")
    local chunk, compileError = loadstring(source)
    assert(type(chunk) == "function", compileError or "[Move] GridDivider loadstring failed")
    GridDividerFactory = chunk()
    assert(type(GridDividerFactory) == "function", "[Move] GridDivider factory invalid")
    Env.JustXPiggyGridDividerFactory = GridDividerFactory
end

local GridDivider = GridDividerFactory({
    Mode = "Move",
    Value = step,
    MinValue = 0.1,
    MaxValue = 10,
    OnChanged = function(value)
        step = value
        Steps.Move = value
    end
})
local cachedFunction
local cachedIndex
local originalConstant

if type(Env.MoveToolCleanup) == "function" then
    pcall(Env.MoveToolCleanup)
end



-- Поиск Move Tool
local function findMoveFunction()
    if cachedFunction and cachedIndex then
        local ok, constants = pcall(debug.getconstants, cachedFunction)

        if ok and constants[cachedIndex] ~= nil then
            return cachedFunction, cachedIndex
        end
    end

    for _, obj in ipairs(getgc(true)) do
        if type(obj) == "table" and getmetatable(obj) == class then
            local handles = obj.MoveHandles

            if handles then
                local ok, connections = pcall(getconnections, handles.MouseDrag)

                if ok and connections then
                    for _, conn in ipairs(connections) do
                        local fn = conn.Function

                        if type(fn) == "function" then
                            local success, constants = pcall(debug.getconstants, fn)

                            if success then
                                local hasSpecialStep = false
                                local target

                                for index, value in pairs(constants) do
                                    if value == 0.0625 then
                                        hasSpecialStep = true
                                    elseif value == 4.5 or value == step then
                                        target = index
                                    end
                                end

                                if hasSpecialStep and target then
                                    cachedFunction = fn
                                    cachedIndex = target
                                    return fn, target
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

local function applyStep()
    local fn, index = findMoveFunction()

    if not fn then
        return false
    end

    if originalConstant == nil then
        local ok, value = pcall(debug.getconstant, fn, index)
        if ok then originalConstant = value end
    end

    return pcall(debug.setconstant, fn, index, step)
end

-- Автоматическое применение


-- Ожидание появления Move Tool
task.spawn(function()
    while GridDivider and GridDivider.Gui and GridDivider.Gui.Parent do
        applyStep()
        task.wait(0.3)
    end
end)

print("[Move] Step input loaded")


-- Toggle cleanup added for JustXPiggy.
local cleaned = false
local function Cleanup()
    if cleaned then return end
    cleaned = true
    if type(Env.JustXPiggyMultiSelectUnregister) == "function" then
        pcall(Env.JustXPiggyMultiSelectUnregister, "Move")
    end
    if cachedFunction and cachedIndex and originalConstant ~= nil then
        pcall(debug.setconstant, cachedFunction, cachedIndex, originalConstant)
    end
    if GridDivider then
        pcall(function() GridDivider:Destroy() end)
    end
    if Env.MoveToolCleanup == Cleanup then
        Env.MoveToolCleanup = nil
    end
    print("[Move] Tool disabled")
end
Env.MoveToolCleanup = Cleanup

-- Shared multi-selection controller for Move, Resize and Rotate.
local MultiSelectOk, MultiSelectError = pcall(function()
    local source = game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustX/main/Games/Piggy/BM/Tools/MultiSelect.lua")
    local chunk, compileError = loadstring(source)
    assert(type(chunk) == "function", compileError or "[Move] MultiSelect loadstring failed")
    local register = chunk()
    if type(register) ~= "function" then
        register = Env.JustXPiggyMultiSelectRegister
    end
    assert(type(register) == "function", "[Move] MultiSelect register function unavailable")
    register("Move")
end)

if not MultiSelectOk then
    Cleanup()
    error("[Move] MultiSelect failed to start: " .. tostring(MultiSelectError), 0)
end
