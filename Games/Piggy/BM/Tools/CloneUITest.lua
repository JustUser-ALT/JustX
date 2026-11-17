--==================================================
-- CLONE UI TEST
-- Standalone visual test; does not clone or move blocks.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")
local BuildModeFolder = RS:WaitForChild("BuildMode")
local BuildingMode = require(BuildModeFolder:WaitForChild("BuildingMode"))
local ChangedEvent = BuildModeFolder:WaitForChild("Events"):WaitForChild("BuildingModeChanged")

local Env = (getgenv and getgenv()) or _G
if type(Env.CloneUITestCleanup) == "function" then
    pcall(Env.CloneUITestCleanup)
end

-- Find the existing native toolbar without changing its contents.
local ClientState
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
assert(ClientState, "[CloneUITest] BuildMode ClientState not found")

local Toolbar = ClientState.Toolbar
local BuildingToolbar = Toolbar and Toolbar.BuildingModeToolbar
local ToolbarFrame = BuildingToolbar and BuildingToolbar.Instance
assert(ToolbarFrame and ToolbarFrame:IsA("GuiObject"),
    "[CloneUITest] Native building toolbar not found")

local OldGui = PlayerGui:FindFirstChild("JustXCloneUITest")
if OldGui then OldGui:Destroy() end

local Gui = Instance.new("ScreenGui")
Gui.Name = "JustXCloneUITest"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = BuildModeGui.IgnoreGuiInset
Gui.DisplayOrder = 10001
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Button = Instance.new("TextButton")
Button.Name = "CloneButton"
Button.AnchorPoint = Vector2.zero
Button.Size = UDim2.fromOffset(90, 88)
Button.BackgroundColor3 = Color3.fromRGB(244, 139, 145)
Button.BorderSizePixel = 0
Button.AutoButtonColor = true
Button.Text = ""
Button.Visible = false
Button.ZIndex = 20
Button.Parent = Gui

local ButtonCorner = Instance.new("UICorner")
ButtonCorner.CornerRadius = UDim.new(0, 18)
ButtonCorner.Parent = Button

local ButtonStroke = Instance.new("UIStroke")
ButtonStroke.Color = Color3.fromRGB(255, 174, 177)
ButtonStroke.Thickness = 1
ButtonStroke.Transparency = 0.35
ButtonStroke.Parent = Button

-- Two offset outlined cards recreate the Concepts clone symbol.
local function MakeCard(name, position, size, zIndex)
    local outer = Instance.new("Frame")
    outer.Name = name .. "Outline"
    outer.Position = position
    outer.Size = size
    outer.BackgroundColor3 = Color3.fromRGB(28, 28, 31)
    outer.BorderSizePixel = 0
    outer.ZIndex = zIndex
    outer.Parent = Button

    local outerCorner = Instance.new("UICorner")
    outerCorner.CornerRadius = UDim.new(0, 4)
    outerCorner.Parent = outer

    local inner = Instance.new("Frame")
    inner.Name = "WhiteFace"
    inner.Position = UDim2.fromOffset(3, 3)
    inner.Size = UDim2.new(1, -6, 1, -6)
    inner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    inner.BorderSizePixel = 0
    inner.ZIndex = zIndex + 1
    inner.Parent = outer

    local innerCorner = Instance.new("UICorner")
    innerCorner.CornerRadius = UDim.new(0, 2)
    innerCorner.Parent = inner
    return outer
end

MakeCard("BackCard", UDim2.fromOffset(30, 17), UDim2.fromOffset(38, 43), 21)
MakeCard("FrontCard", UDim2.fromOffset(21, 27), UDim2.fromOffset(38, 43), 23)

local Label = Instance.new("TextLabel")
Label.Name = "CloneLabel"
Label.BackgroundTransparency = 1
Label.Position = UDim2.fromOffset(0, 33)
Label.Size = UDim2.new(1, 0, 0, 23)
Label.Font = Enum.Font.GothamBlack
Label.Text = "CLONE"
Label.TextSize = 15
Label.TextColor3 = Color3.fromRGB(24, 24, 27)
Label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
Label.TextStrokeTransparency = 0.2
Label.ZIndex = 25
Label.Parent = Button

local function UpdatePosition()
    if not Gui.Parent or not ToolbarFrame.Parent then return end

    local height = math.clamp(ToolbarFrame.AbsoluteSize.Y * 0.733, 64, 90)
    local width = height
    local gap = math.max(10, height * 0.12)

    Button.Size = UDim2.fromOffset(width, height)
    Button.Position = UDim2.fromOffset(
        ToolbarFrame.AbsolutePosition.X - width - gap,
        ToolbarFrame.AbsolutePosition.Y + (ToolbarFrame.AbsoluteSize.Y - height) * 0.5
    )
end

local function GetModeName()
    local mode = BuildingMode:Get()
    return mode and (mode.Name or tostring(mode):match("([^%.]+)$")) or "None"
end

local function UpdateVisibility(modeName)
    Button.Visible = modeName == "Move"
    if Button.Visible then
        UpdatePosition()
    end
end

local Connections = {}
table.insert(Connections, ChangedEvent.Event:Connect(UpdateVisibility))
table.insert(Connections, ToolbarFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(UpdatePosition))
table.insert(Connections, ToolbarFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdatePosition))

Button.Activated:Connect(function()
    warn("[CloneUITest] UI only — clone behavior is not connected yet.")
end)

UpdateVisibility(GetModeName())

local Cleaned = false
local function Cleanup()
    if Cleaned then return end
    Cleaned = true

    for _, connection in ipairs(Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(Connections)

    if Gui and Gui.Parent then
        Gui:Destroy()
    end

    if Env.CloneUITestCleanup == Cleanup then
        Env.CloneUITestCleanup = nil
    end
    print("[CloneUITest] Cleaned up")
end

Env.CloneUITestCleanup = Cleanup
print("[CloneUITest] Loaded — button is visible only in Move mode.")
