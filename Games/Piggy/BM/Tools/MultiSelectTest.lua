--==================================================
-- MULTI SELECT TEST
-- Isolated selection prototype for Piggy Build Mode.
-- Supports selection visuals and group-center preview only.
-- Does not modify Move / Rotate / Resize tool implementations.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")
local Main = BuildModeGui:WaitForChild("Main")
local BuildModel = workspace:WaitForChild("BuildModel")

local BuildModeFolder = RS:WaitForChild("BuildMode")
local BuildingMode = require(BuildModeFolder:WaitForChild("BuildingMode"))
local ChangedEvent = BuildModeFolder:WaitForChild("Events"):WaitForChild("BuildingModeChanged")
local PlacementLogic = require(BuildModeFolder:WaitForChild("PlacementLogic"))

local Env = (getgenv and getgenv()) or _G

if type(Env.MultiSelectTestCleanup) == "function" then
    pcall(Env.MultiSelectTestCleanup)
end

assert(type(getsenv) == "function", "[MultiSelectTest] getsenv unavailable")
local MainEnv = getsenv(Main)
local ClientState = MainEnv and MainEnv._G and MainEnv._G.BuildModeClient

assert(type(ClientState) == "table", "[MultiSelectTest] BuildModeClient not found")
assert(type(ClientState.PlaceBlockAction) == "function", "[MultiSelectTest] PlaceBlockAction missing")

local OriginalPlaceBlockAction = ClientState.PlaceBlockAction
local Placement = PlacementLogic.new()

-- This test runs as a LocalScript, so keep its UI inside PlayerGui.
-- CoreGui / gethui may be inaccessible from this execution context.
local GuiParent = PlayerGui

local oldGui = GuiParent:FindFirstChild("JustXMultiSelectTest")
if oldGui then
    oldGui:Destroy()
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "JustXMultiSelectTest"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 10001
Gui.Enabled = false
Gui.Parent = GuiParent

local Toggle = Instance.new("TextButton")
Toggle.Name = "MultiSelectToggle"
Toggle.Size = UDim2.fromOffset(92, 42)
Toggle.Position = UDim2.new(1, -104, 0.56, 0)
Toggle.BackgroundColor3 = Color3.fromRGB(42, 46, 55)
Toggle.BorderSizePixel = 0
Toggle.Text = "MULTI  OFF"
Toggle.TextColor3 = Color3.fromRGB(235, 238, 245)
Toggle.TextSize = 13
Toggle.Font = Enum.Font.GothamBold
Toggle.AutoButtonColor = true
Toggle.Visible = false
Toggle.Parent = Gui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 9)
ToggleCorner.Parent = Toggle

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(105, 115, 135)
ToggleStroke.Thickness = 1
ToggleStroke.Transparency = 0.2
ToggleStroke.Parent = Toggle

local Status = Instance.new("TextLabel")
Status.Name = "SelectionCount"
Status.Size = UDim2.fromOffset(92, 20)
Status.Position = UDim2.new(1, -104, 0.56, 44)
Status.BackgroundTransparency = 1
Status.Text = "0 selected"
Status.TextColor3 = Color3.fromRGB(220, 225, 235)
Status.TextSize = 11
Status.Font = Enum.Font.Gotham
Status.Visible = false
Status.Parent = Gui

local Selection = {}
local Highlights = {}
local MultiEnabled = false
local Cleaned = false
local Connections = {}

local function GetModeName(mode)
    if mode == nil then
        return ""
    end

    local ok, name = pcall(function()
        return mode.Name
    end)

    if ok and type(name) == "string" then
        return name
    end

    return tostring(mode):match("([^%.]+)$") or tostring(mode)
end

local function IsSupportedMode()
    local name = GetModeName(BuildingMode:Get())
    return name == "Move" or name == "Rotate" or name == "Resize"
end

local function IsValidBlock(block)
    return typeof(block) == "Instance"
        and block:IsA("Model")
        and block.Parent == BuildModel
end

local function UpdateStatus()
    Status.Text = tostring(#Selection) .. " selected"
    Toggle.Text = MultiEnabled and "MULTI  ON" or "MULTI  OFF"
    Toggle.BackgroundColor3 = MultiEnabled
        and Color3.fromRGB(75, 125, 95)
        or Color3.fromRGB(42, 46, 55)
end

local function GetSelectionIndex(block)
    for index, selected in ipairs(Selection) do
        if selected == block then
            return index
        end
    end
    return nil
end

local function RemoveHighlight(block)
    local highlight = Highlights[block]
    if highlight then
        Highlights[block] = nil
        pcall(function()
            highlight:Destroy()
        end)
    end
end

local function AddHighlight(block)
    if Highlights[block] then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "JustXMultiSelectHighlight"
    highlight.Adornee = block
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Color3.fromRGB(145, 105, 255)
    highlight.FillTransparency = 0.88
    highlight.OutlineColor = Color3.fromRGB(185, 155, 255)
    highlight.OutlineTransparency = 0
    highlight.Parent = Gui
    Highlights[block] = highlight
end

local CenterMarker = Instance.new("Part")
CenterMarker.Name = "JustXMultiSelectCenter"
CenterMarker.Shape = Enum.PartType.Ball
CenterMarker.Size = Vector3.new(0.28, 0.28, 0.28)
CenterMarker.Anchored = true
CenterMarker.CanCollide = false
CenterMarker.CanTouch = false
CenterMarker.CanQuery = false
CenterMarker.CastShadow = false
CenterMarker.Material = Enum.Material.Neon
CenterMarker.Color = Color3.fromRGB(190, 155, 255)
CenterMarker.Transparency = 0.05
CenterMarker.Parent = workspace
CenterMarker.LocalTransparencyModifier = 0
CenterMarker.Transparency = 1

local function UpdateCenter()
    local total = Vector3.zero
    local count = 0

    for index = #Selection, 1, -1 do
        local block = Selection[index]
        if IsValidBlock(block) then
            total += block:GetPivot().Position
            count += 1
        else
            table.remove(Selection, index)
            RemoveHighlight(block)
        end
    end

    if count > 0 then
        CenterMarker.Position = total / count
        CenterMarker.Transparency = count > 1 and 0 or 1
    else
        CenterMarker.Transparency = 1
    end

    UpdateStatus()
end

local function SetNativeSelection()
    local selected = Selection[#Selection]
    if selected and IsValidBlock(selected) then
        ClientState.SelectedBlock = selected
    else
        ClientState.SelectedBlock = nil
    end
end

local function ClearSelection()
    for block in pairs(Highlights) do
        RemoveHighlight(block)
    end
    table.clear(Selection)
    SetNativeSelection()
    UpdateCenter()
end

local function ToggleBlock(block)
    if not IsValidBlock(block) then
        return
    end

    local index = GetSelectionIndex(block)
    if index then
        table.remove(Selection, index)
        RemoveHighlight(block)
        print("[MultiSelectTest] Removed:", block:GetFullName())
    else
        table.insert(Selection, block)
        AddHighlight(block)
        print("[MultiSelectTest] Added:", block:GetFullName())
    end

    SetNativeSelection()
    UpdateCenter()
end

local function GetHoveredBlock()
    local ok, result = pcall(function()
        return Placement:Raycast()
    end)

    if not ok or not result or not result.Instance then
        return nil
    end

    local candidate = result.Instance:FindFirstAncestorWhichIsA("Model")
    if IsValidBlock(candidate) then
        return candidate
    end

    return nil
end

local function MultiSelectAction(state, ...)
    if Cleaned or not MultiEnabled or not IsSupportedMode() then
        return OriginalPlaceBlockAction(state, ...)
    end

    local block = GetHoveredBlock()
    if block then
        ToggleBlock(block)
    end

    return Enum.ContextActionResult.Sink
end

local function UpdateModeVisibility()
    local visible = IsSupportedMode()
    Gui.Enabled = visible
    Toggle.Visible = visible
    Status.Visible = visible
end

table.insert(Connections, Toggle.Activated:Connect(function()
    if not IsSupportedMode() then
        return
    end

    MultiEnabled = not MultiEnabled

    if not MultiEnabled then
        ClearSelection()
    else
        print("[MultiSelectTest] Multi Select enabled")
    end

    UpdateStatus()
end))

table.insert(Connections, ChangedEvent.Event:Connect(function()
    task.defer(UpdateModeVisibility)
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if Cleaned then
        return
    end

    UpdateCenter()
end))

ClientState.PlaceBlockAction = MultiSelectAction
UpdateModeVisibility()
UpdateStatus()

local function Cleanup()
    if Cleaned then
        return
    end
    Cleaned = true

    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(Connections)

    if ClientState.PlaceBlockAction == MultiSelectAction then
        ClientState.PlaceBlockAction = OriginalPlaceBlockAction
    end

    ClearSelection()
    MultiEnabled = false

    pcall(function()
        CenterMarker:Destroy()
    end)
    pcall(function()
        Gui:Destroy()
    end)

    if Env.MultiSelectTestCleanup == Cleanup then
        Env.MultiSelectTestCleanup = nil
    end

    print("[MultiSelectTest] Cleanup complete")
end

Env.MultiSelectTestCleanup = Cleanup

print("================================")
print("[MultiSelectTest] Loaded")
print("[MultiSelectTest] Toggle: Move / Rotate / Resize only")
print("[MultiSelectTest] Multi-selection + per-block outlines: READY")
print("[MultiSelectTest] Group center preview: READY")
print("[MultiSelectTest] Group transforms: NOT IMPLEMENTED IN THIS TEST")
print("[MultiSelectTest] Use MultiSelectTestCleanup() to unload")
print("================================")
