local Env = (getgenv and getgenv()) or _G
local RS = game:GetService("ReplicatedStorage")
local BMC = require(RS.BuildMode.BuildModeClient)

local class = debug.getupvalues(BMC.new)[3]
assert(class, "BuildModeClient class not found")

local Steps = type(Env.JustXPiggyToolSteps) == "table" and Env.JustXPiggyToolSteps or {}
Env.JustXPiggyToolSteps = Steps
local step = tonumber(Steps.Move) or 0.1
Steps.Move = step
local cachedFunction
local cachedIndex
local originalConstant

if type(Env.MoveToolCleanup) == "function" then
    pcall(Env.MoveToolCleanup)
end

local guiParent = gethui and gethui() or game:GetService("CoreGui")

local old = guiParent:FindFirstChild("MoveStepSettings")
if old then
    old:Destroy()
end

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "MoveStepSettings"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10000
gui.Enabled = false
gui.Parent = guiParent

local input = Instance.new("TextBox")
input.Name = "StepInput"
input.Size = UDim2.fromOffset(55, 25)
input.Position = UDim2.new(1, -65, 0.46, 0)
input.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
input.BorderSizePixel = 0
input.TextColor3 = Color3.new(1, 1, 1)
input.Text = tostring(step)
input.PlaceholderText = tostring(step)
input.Font = Enum.Font.Gotham
input.TextSize = 12
input.ClearTextOnFocus = false
input.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 5)
corner.Parent = input

-- Mode-aware visibility and independent saved step.
local BuildModeFolder = RS:WaitForChild("BuildMode")
local BuildingMode = require(BuildModeFolder:WaitForChild("BuildingMode"))
local ChangedEvent = BuildModeFolder:WaitForChild("Events"):WaitForChild("BuildingModeChanged")
local function UpdateStepVisibility(modeName)
    gui.Enabled = modeName == "Move"
end
local currentMode = BuildingMode:Get()
local currentModeName = tostring(currentMode):match("([^%.]+)$")
gui.Enabled = currentModeName == "Move"
local ModeConnection = ChangedEvent.Event:Connect(UpdateStepVisibility)

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
input.FocusLost:Connect(function()
    local value = tonumber(input.Text)

    if not value then
        input.Text = tostring(step)
        return
    end

    step = math.clamp(value, 0.1, 10)
    Steps.Move = step
    input.Text = tostring(step)

    applyStep()
end)

-- Ожидание появления Move Tool
task.spawn(function()
    while gui.Parent do
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
    if cachedFunction and cachedIndex and originalConstant ~= nil then
        pcall(debug.setconstant, cachedFunction, cachedIndex, originalConstant)
    end
    if ModeConnection then
        pcall(function() ModeConnection:Disconnect() end)
    end
    if gui and gui.Parent then
        pcall(function() gui:Destroy() end)
    end
    if Env.MoveToolCleanup == Cleanup then
        Env.MoveToolCleanup = nil
    end
    print("[Move] Tool disabled")
end
Env.MoveToolCleanup = Cleanup
