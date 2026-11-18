--==================================================
-- MULTI SELECT TEST
-- Multi-selection prototype for Piggy Build Mode.
-- Selection visuals use the same BoxSelectionAdornment
-- implementation as the working Rotate tool.
-- Group transforms are not implemented in this test.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")
local BuildModel = workspace:WaitForChild("BuildModel")

local BuildModeFolder = RS:WaitForChild("BuildMode")
local BuildingMode = require(BuildModeFolder:WaitForChild("BuildingMode"))
local ChangedEvent = BuildModeFolder:WaitForChild("Events"):WaitForChild("BuildingModeChanged")
local PlacementLogic = require(BuildModeFolder:WaitForChild("PlacementLogic"))
local BoxSelectionAdornment = require(
    RS:WaitForChild("Packages")
        :WaitForChild("CustomAdornments")
        :WaitForChild("BoxSelectionAdornment")
)

local Env = (getgenv and getgenv()) or _G

if type(Env.MultiSelectTestCleanup) == "function" then
    pcall(Env.MultiSelectTestCleanup)
end

-- Find ClientState the same way as the working Rotate tool.
local ClientState
assert(type(getgc) == "function", "[MultiSelectTest] getgc unavailable")

for attempt = 1, 100 do
    for _, object in ipairs(getgc(true)) do
        if type(object) == "table"
            and rawget(object, "ScreenGui") == BuildModeGui
            and rawget(object, "Toolbar")
            and type(rawget(object, "PlaceBlockAction")) == "function" then
            ClientState = object
            break
        end
    end

    if ClientState then
        break
    end

    task.wait(0.1)
end

assert(ClientState, "[MultiSelectTest] BuildModeClient not found")
local OriginalPlaceBlockAction = ClientState.PlaceBlockAction

local Placement = PlacementLogic.new()
local AdornmentParent = BuildModeGui:WaitForChild("Frame"):WaitForChild("Adornment")

-- UI belongs to PlayerGui; this also works in ordinary LocalScript context.
local oldGui = PlayerGui:FindFirstChild("JustXMultiSelectTest")
if oldGui then
    oldGui:Destroy()
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "JustXMultiSelectTest"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 10001
Gui.Enabled = false
Gui.Parent = PlayerGui

local Toggle = Instance.new("TextButton")
Toggle.Name = "MultiSelectToggle"
Toggle.Size = UDim2.fromOffset(96, 42)
Toggle.Position = UDim2.new(1, -108, 0.56, 0)
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
Status.Size = UDim2.fromOffset(96, 20)
Status.Position = UDim2.new(1, -108, 0.56, 44)
Status.BackgroundTransparency = 1
Status.Text = "0 selected"
Status.TextColor3 = Color3.fromRGB(220, 225, 235)
Status.TextSize = 11
Status.Font = Enum.Font.Gotham
Status.Visible = false
Status.Parent = Gui

local Selection = {}
local SelectionOutlines = {}
local HoverOutline = BoxSelectionAdornment.new()
HoverOutline:SetParent(AdornmentParent)
HoverOutline:SetColor(Color3.fromRGB(0, 0, 255))
HoverOutline:SetThickness(0.03)
HoverOutline:SetAdornee(nil)

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

local function GetToolColor()
    local modeName = GetModeName(BuildingMode:Get())

    if modeName == "Move" then
        return Color3.fromRGB(0, 0, 255)
    elseif modeName == "Rotate" then
        return Color3.fromRGB(170, 85, 255)
    elseif modeName == "Resize" then
        return Color3.fromRGB(255, 128, 0)
    end

    return Color3.fromRGB(0, 0, 255)
end

local function UpdateStatus()
    Status.Text = tostring(#Selection) .. " selected"
    Toggle.Text = MultiEnabled and "MULTI  ON" or "MULTI  OFF"
    Toggle.BackgroundColor3 = MultiEnabled
        and Color3.fromRGB(75, 125, 95)
        or Color3.fromRGB(42, 46, 55)
end

local function FindSelectionIndex(block)
    for index, selected in ipairs(Selection) do
        if selected == block then
            return index
        end
    end
    return nil
end

local function CreateSelectionOutline(block)
    local outline = BoxSelectionAdornment.new()
    outline:SetParent(AdornmentParent)
    outline:SetColor(GetToolColor())
    outline:SetThickness(0.1)
    outline:SetAdornee(block)
    SelectionOutlines[block] = outline
end

local function RemoveSelectionOutline(block)
    local outline = SelectionOutlines[block]
    if outline then
        SelectionOutlines[block] = nil
        pcall(function()
            outline:SetAdornee(nil)
            outline:Destroy()
        end)
    end
end

local function UpdateSelectionOutlineColors()
    local color = GetToolColor()

    for _, outline in pairs(SelectionOutlines) do
        pcall(function()
            outline:SetColor(color)
        end)
    end
end

local function SetNativeSelection()
    local last = Selection[#Selection]
    if IsValidBlock(last) then
        ClientState.SelectedBlock = last
    end
end

local function UpdateStatusAndNativeSelection()
    UpdateStatus()
    if MultiEnabled then
        SetNativeSelection()
    end
end

local function ClearSelection()
    for block in pairs(SelectionOutlines) do
        RemoveSelectionOutline(block)
    end
    table.clear(Selection)
    UpdateStatus()
end

local function DisableMultiSelect()
    local last = Selection[#Selection]

    MultiEnabled = false
    HoverOutline:SetAdornee(nil)

    for block in pairs(SelectionOutlines) do
        RemoveSelectionOutline(block)
    end

    table.clear(Selection)

    -- Transfer the last multi-selected block to the native single selection.
    -- Do not clear SelectedBlock when the multi-selection was empty.
    if IsValidBlock(last) then
        ClientState.SelectedBlock = last
    end

    UpdateStatus()
end

local function ToggleBlock(block)
    if not IsValidBlock(block) then
        return
    end

    local index = FindSelectionIndex(block)
    if index then
        table.remove(Selection, index)
        RemoveSelectionOutline(block)
        print("[MultiSelectTest] Removed:", block:GetFullName())
    else
        table.insert(Selection, block)
        CreateSelectionOutline(block)
        print("[MultiSelectTest] Added:", block:GetFullName())
    end

    UpdateStatusAndNativeSelection()
end

-- Match the proven Rotate tool raycast target convention:
-- PlacementLogic:Raycast() result.Instance.Parent is the build block Model.
local function GetHoveredBlock()
    local ok, result = pcall(function()
        return Placement:Raycast()
    end)

    if not ok or not result or not result.Instance then
        return nil
    end

    local candidate = result.Instance.Parent
    if IsValidBlock(candidate) then
        return candidate
    end

    return nil
end

local function UpdateHoverOutline()
    if not IsSupportedMode() then
        HoverOutline:SetAdornee(nil)
        return
    end

    HoverOutline:SetColor(GetToolColor())

    local hovered = GetHoveredBlock()
    if hovered and FindSelectionIndex(hovered) then
        hovered = nil
    end

    HoverOutline:SetAdornee(hovered)
end

local function MultiSelectPlaceBlockAction(self, ...)
    local mode = BuildingMode:Get()
    local modeName = GetModeName(mode)

    if Cleaned
        or not MultiEnabled
        or (modeName ~= "Move" and modeName ~= "Rotate" and modeName ~= "Resize") then
        return OriginalPlaceBlockAction(self, ...)
    end

    local block = GetHoveredBlock()
    if block then
        ToggleBlock(block)
    else
        print("[MultiSelectTest] Click ignored: no BuildModel block under pointer")
    end

    return Enum.ContextActionResult.Sink
end

local function UpdateModeVisibility(modeName)
    local visible
    if type(modeName) == "string" then
        visible = modeName == "Move" or modeName == "Rotate" or modeName == "Resize"
    else
        visible = IsSupportedMode()
    end

    Gui.Enabled = visible
    Toggle.Visible = visible
    Status.Visible = visible

    if not visible then
        HoverOutline:SetAdornee(nil)
    end
end

table.insert(Connections, Toggle.Activated:Connect(function()
    if not IsSupportedMode() then
        return
    end

    MultiEnabled = not MultiEnabled

    if not MultiEnabled then
        DisableMultiSelect()
        print("[MultiSelectTest] Multi Select disabled; native tool restored")
    else
        print("[MultiSelectTest] Multi Select enabled")
    end

    UpdateStatus()
end))

table.insert(Connections, ChangedEvent.Event:Connect(function(modeName)
    task.defer(function()
        UpdateModeVisibility(modeName)
    end)
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if Cleaned then
        return
    end

    -- Keep invalid/deleted models out of the active selection.
    for index = #Selection, 1, -1 do
        local block = Selection[index]
        if not IsValidBlock(block) then
            table.remove(Selection, index)
            RemoveSelectionOutline(block)
        end
    end

    if MultiEnabled and IsSupportedMode() then
        UpdateSelectionOutlineColors()
        UpdateHoverOutline()
    else
        HoverOutline:SetAdornee(nil)
    end

    if MultiEnabled then
        UpdateStatusAndNativeSelection()
    else
        UpdateStatus()
    end
end))

ClientState.PlaceBlockAction = MultiSelectPlaceBlockAction
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

    if ClientState.PlaceBlockAction == MultiSelectPlaceBlockAction then
        ClientState.PlaceBlockAction = OriginalPlaceBlockAction
    end

    ClearSelection()

    pcall(function()
        HoverOutline:SetAdornee(nil)
        HoverOutline:Destroy()
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
print("[MultiSelectTest] ClientState: FOUND")
print("[MultiSelectTest] Hover outline: READY")
print("[MultiSelectTest] Multi-selection outlines: READY")
print("[MultiSelectTest] Group transforms: NOT IMPLEMENTED")
print("[MultiSelectTest] Use MultiSelectTestCleanup() to unload")
print("================================")
