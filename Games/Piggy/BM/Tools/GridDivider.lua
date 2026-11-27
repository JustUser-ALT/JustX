--==================================================
-- JUSTX GRID DIVIDER
-- Shared step control for Move, Resize and Rotate.
-- Extracted from the MultiMoveTest Grid Divider UI.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local function CreateGridDivider(options)
    options = options or {}

    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local modeName = tostring(options.Mode or "")
    assert(modeName ~= "", "[GridDivider] Mode is required")

    local BuildModeFolder = RS:WaitForChild("BuildMode")
    local BuildingMode = require(BuildModeFolder:WaitForChild("BuildingMode"))
    local ChangedEvent = BuildModeFolder:WaitForChild("Events"):WaitForChild("BuildingModeChanged")

    local old = playerGui:FindFirstChild("JustX" .. modeName .. "GridDivider")
    if old then
        old:Destroy()
    end

    local Gui = Instance.new("ScreenGui")
    Gui.Name = "JustX" .. modeName .. "GridDivider"
    Gui.ResetOnSpawn = false
    Gui.IgnoreGuiInset = true
    Gui.DisplayOrder = 10001
    Gui.Enabled = false

    local GridLabel = Instance.new("TextLabel")
    GridLabel.Name = "GridDividerLabel"
    GridLabel.Size = UDim2.fromOffset(72, 16)
    GridLabel.Position = UDim2.new(0, 226, 1, -79)
    GridLabel.AnchorPoint = Vector2.new(0, 1)
    GridLabel.BackgroundTransparency = 1
    GridLabel.Text = "Grid Divider"
    GridLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    GridLabel.TextSize = 11
    GridLabel.Font = Enum.Font.Gotham
    GridLabel.TextXAlignment = Enum.TextXAlignment.Center
    GridLabel.ZIndex = 3
    GridLabel.Visible = false
    GridLabel.Parent = Gui

    local GridDivider = Instance.new("TextBox")
    GridDivider.Name = "GridDivider"
    GridDivider.Size = UDim2.fromOffset(55, 25)
    GridDivider.Position = UDim2.new(0, 226, 1, -34)
    GridDivider.AnchorPoint = Vector2.new(0, 1)
    GridDivider.BackgroundColor3 = Color3.fromRGB(255, 142, 142)
    GridDivider.BorderSizePixel = 0
    GridDivider.Text = tostring(tonumber(options.Value) or 1)
    GridDivider.PlaceholderText = GridDivider.Text
    GridDivider.TextColor3 = Color3.new(1, 1, 1)
    GridDivider.TextSize = 12
    GridDivider.Font = Enum.Font.Gotham
    GridDivider.ClearTextOnFocus = false
    GridDivider.ZIndex = 3
    GridDivider.Visible = false
    GridDivider.Parent = Gui

    -- Match the original Piggy Build Mode Concepts MoveSnap control
    -- whenever that template is available in the current UI.
    local BuildGui = playerGui:FindFirstChild("BuildGui")
    local Toolbar = BuildGui and BuildGui:FindFirstChild("Toolbar")
    local Exception = Toolbar and Toolbar:FindFirstChild("Exception")
    local MoveSnapTemplate = Exception and Exception:FindFirstChild("MoveSnap")

    if MoveSnapTemplate and MoveSnapTemplate:IsA("TextBox") then
        local styleProperties = {
            "BackgroundColor3",
            "BackgroundTransparency",
            "BorderColor3",
            "BorderMode",
            "BorderSizePixel",
            "TextColor3",
            "TextTransparency",
            "TextStrokeColor3",
            "TextStrokeTransparency",
            "TextSize",
            "TextScaled",
            "TextWrapped",
            "TextXAlignment",
            "TextYAlignment",
            "Font",
            "ClearTextOnFocus",
            "PlaceholderColor3",
            "PlaceholderText"
        }

        for _, property in ipairs(styleProperties) do
            pcall(function()
                GridDivider[property] = MoveSnapTemplate[property]
            end)
        end

        local templateSize = MoveSnapTemplate.AbsoluteSize
        if templateSize.X > 0 and templateSize.Y > 0 then
            GridDivider.Size = UDim2.fromOffset(templateSize.X, templateSize.Y)
        end

        for _, child in ipairs(MoveSnapTemplate:GetChildren()) do
            if child:IsA("UICorner") or child:IsA("UIStroke") or child:IsA("UIGradient") then
                child:Clone().Parent = GridDivider
            end
        end
    else
        GridDivider.BackgroundColor3 = Color3.fromRGB(255, 142, 142)
        GridDivider.BackgroundTransparency = 0
        GridDivider.TextColor3 = Color3.new(0, 0, 0)
        GridDivider.TextSize = 12
        GridDivider.Font = Enum.Font.Gotham
    end

    local rounded = GridDivider:FindFirstChildOfClass("UICorner")
    if not rounded then
        rounded = Instance.new("UICorner")
        rounded.Parent = GridDivider
    end
    rounded.CornerRadius = UDim.new(0, 8)

    -- Final layout from the approved MultiMoveTest preview.
    GridDivider.Size = UDim2.fromOffset(72, 34)
    GridDivider.TextSize = 16
    GridDivider.TextScaled = false

    Gui.Parent = playerGui

    local value = tonumber(options.Value) or 1
    GridDivider.Text = tostring(value)

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

    local function UpdateVisibility(mode)
        local visible = GetModeName(mode or BuildingMode:Get()) == modeName
        Gui.Enabled = visible
        GridLabel.Visible = visible
        GridDivider.Visible = visible
    end

    local FocusConnection = GridDivider.FocusLost:Connect(function()
        local parsed = tonumber(GridDivider.Text)
        if not parsed then
            GridDivider.Text = tostring(value)
            return
        end

        value = math.clamp(
            parsed,
            tonumber(options.MinValue) or 0.1,
            tonumber(options.MaxValue) or 10
        )
        GridDivider.Text = tostring(value)

        if type(options.OnChanged) == "function" then
            options.OnChanged(value)
        end
    end)

    local ModeConnection = ChangedEvent.Event:Connect(UpdateVisibility)
    UpdateVisibility(BuildingMode:Get())

    local destroyed = false
    local Control = {
        Gui = Gui,
        Input = GridDivider,
        Label = GridLabel
    }

    function Control:GetValue()
        return value
    end

    function Control:SetValue(newValue)
        local parsed = tonumber(newValue)
        if not parsed then
            return false
        end

        value = math.clamp(
            parsed,
            tonumber(options.MinValue) or 0.1,
            tonumber(options.MaxValue) or 10
        )
        GridDivider.Text = tostring(value)

        if type(options.OnChanged) == "function" then
            options.OnChanged(value)
        end
        return true
    end

    function Control:Destroy()
        if destroyed then
            return
        end
        destroyed = true

        pcall(function()
            FocusConnection:Disconnect()
        end)
        pcall(function()
            ModeConnection:Disconnect()
        end)
        pcall(function()
            Gui:Destroy()
        end)
    end

    return Control
end

return CreateGridDivider
