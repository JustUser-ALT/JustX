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

-- Find the native toolbar and use its parent coordinate space.
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

local BuildingToolbar = ClientState.Toolbar and ClientState.Toolbar.BuildingModeToolbar
local ToolbarFrame = BuildingToolbar and BuildingToolbar.Instance
assert(ToolbarFrame and ToolbarFrame:IsA("GuiObject") and ToolbarFrame.Parent,
    "[CloneUITest] Native building toolbar not found")

local Parent = ToolbarFrame.Parent
assert(Parent:IsA("GuiObject"), "[CloneUITest] Toolbar parent is not a GuiObject")

local OldButton = Parent:FindFirstChild("JustXCloneButton")
if OldButton then OldButton:Destroy() end

local Button = Instance.new("TextButton")
Button.Name = "JustXCloneButton"
Button.AnchorPoint = Vector2.zero
Button.BackgroundColor3 = Color3.fromRGB(244, 139, 145)
Button.BorderSizePixel = 0
Button.AutoButtonColor = true
Button.Text = ""
Button.Visible = false
Button.ZIndex = ToolbarFrame.ZIndex + 10
Button.Parent = Parent

local ButtonCorner = Instance.new("UICorner")
ButtonCorner.CornerRadius = UDim.new(0, 18)
ButtonCorner.Parent = Button

local ButtonStroke = Instance.new("UIStroke")
ButtonStroke.Color = Color3.fromRGB(255, 174, 177)
ButtonStroke.Thickness = 1
ButtonStroke.Transparency = 0.35
ButtonStroke.Parent = Button

-- Scale the complete symbol with the button so nothing overflows.
local IconArea = Instance.new("Frame")
IconArea.Name = "IconArea"
IconArea.BackgroundTransparency = 1
IconArea.AnchorPoint = Vector2.new(0.5, 0.5)
IconArea.Position = UDim2.fromScale(0.5, 0.49)
IconArea.Size = UDim2.fromScale(0.72, 0.72)
IconArea.ZIndex = Button.ZIndex + 1
IconArea.Parent = Button

local function MakeCard(name, position, zIndex)
    local card = Instance.new("Frame")
    card.Name = name
    card.Position = position
    card.Size = UDim2.fromScale(0.64, 0.78)
    card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    card.BorderSizePixel = 0
    card.ZIndex = zIndex
    card.Parent = IconArea

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(28, 28, 31)
    stroke.Thickness = 3
    stroke.Parent = card
    return card
end

MakeCard("BackCard", UDim2.fromScale(0.34, 0.02), Button.ZIndex + 1)
MakeCard("FrontCard", UDim2.fromScale(0.02, 0.20), Button.ZIndex + 2)

local Label = Instance.new("TextLabel")
Label.Name = "CloneLabel"
Label.BackgroundTransparency = 1
Label.AnchorPoint = Vector2.new(0.5, 0.5)
Label.Position = UDim2.fromScale(0.5, 0.57)
Label.Size = UDim2.fromScale(1.15, 0.34)
Label.Font = Enum.Font.GothamBlack
Label.Text = "CLONE"
Label.TextScaled = true
Label.TextColor3 = Color3.fromRGB(24, 24, 27)
Label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
Label.TextStrokeTransparency = 0.15
Label.ZIndex = Button.ZIndex + 4
Label.Parent = IconArea

local function UpdatePosition()
    if not Button.Parent or not ToolbarFrame.Parent then return end

    local parentSize = Parent.AbsoluteSize
    if parentSize.X <= 0 or parentSize.Y <= 0 then return end

    local toolbarPosition = ToolbarFrame.AbsolutePosition
    local parentPosition = Parent.AbsolutePosition
    local toolbarSize = ToolbarFrame.AbsoluteSize

    local buttonHeight = math.clamp(toolbarSize.Y * 0.733, 64, 90)
    local buttonWidth = buttonHeight
    local gap = math.max(10, buttonHeight * 0.12)

    local x = toolbarPosition.X - parentPosition.X - buttonWidth - gap
    local y = toolbarPosition.Y - parentPosition.Y + (toolbarSize.Y - buttonHeight) * 0.5

    Button.Size = UDim2.fromScale(buttonWidth / parentSize.X, buttonHeight / parentSize.Y)
    Button.Position = UDim2.fromScale(x / parentSize.X, y / parentSize.Y)
end

local function GetModeName()
    local mode = BuildingMode:Get()
    return mode and (mode.Name or tostring(mode):match("([^%.]+)$")) or "None"
end

local function UpdateVisibility(modeName)
    Button.Visible = modeName == "Move"
    if Button.Visible then UpdatePosition() end
end

local Connections = {}
table.insert(Connections, ChangedEvent.Event:Connect(UpdateVisibility))
table.insert(Connections, ToolbarFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(UpdatePosition))
table.insert(Connections, ToolbarFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdatePosition))
table.insert(Connections, Parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdatePosition))
table.insert(Connections, Parent:GetPropertyChangedSignal("AbsolutePosition"):Connect(UpdatePosition))

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

    if Button and Button.Parent then Button:Destroy() end
    if Env.CloneUITestCleanup == Cleanup then Env.CloneUITestCleanup = nil end
    print("[CloneUITest] Cleaned up")
end

Env.CloneUITestCleanup = Cleanup
print("[CloneUITest] Loaded — UI only, visible in Move mode.")
