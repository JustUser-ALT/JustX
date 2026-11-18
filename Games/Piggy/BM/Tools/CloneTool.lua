--==================================================
-- CLONE TOOL
-- Contextual Clone button for the native Build Mode Move tool.
-- Recreates the source game's button; does not add a toolbar mode.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")
local Main = BuildModeGui:WaitForChild("Main")
local BuildModel = workspace:WaitForChild("BuildModel")

local BuildModeFolder = RS:WaitForChild("BuildMode")
local BuildingMode = require(BuildModeFolder:WaitForChild("BuildingMode"))
local Enumeration = require(BuildModeFolder:WaitForChild("Common"):WaitForChild("Enumeration"))
local MoveMode = Enumeration.BuildingMode.Move
local ChangedEvent = BuildModeFolder:WaitForChild("Events"):WaitForChild("BuildingModeChanged")

local Functions = RS:WaitForChild("Functions")
local PlaceBlock = Functions:WaitForChild("PlaceBlock")
local CommitMove = Functions:WaitForChild("CommitMove")
local CommitResize = Functions:WaitForChild("CommitResize")

local Env = getgenv()
if type(Env.CloneToolCleanup) == "function" then
    pcall(Env.CloneToolCleanup)
end

--==================================================
-- LIVE BUILD MODE STATE
--==================================================

assert(type(getsenv) == "function", "[CloneTool] getsenv is unavailable")
local MainEnv = getsenv(Main)
local ClientState = MainEnv and MainEnv._G and MainEnv._G.BuildModeClient
assert(type(ClientState) == "table", "[CloneTool] Live BuildModeClient not found")
assert(type(ClientState.PlaceBlockAction) == "function", "[CloneTool] PlaceBlockAction missing")

--==================================================
-- CLONE BUTTON UI
-- Recreated from the source game's visual diagnostics.
--==================================================

local GuiParent
pcall(function()
    if type(gethui) == "function" then
        GuiParent = gethui()
    end
end)
GuiParent = GuiParent or CoreGui

local OldGui = GuiParent:FindFirstChild("JustXCloneButton")
if OldGui then
    OldGui:Destroy()
end

local CloneGui = Instance.new("ScreenGui")
CloneGui.Name = "JustXCloneButton"
CloneGui.ResetOnSpawn = false
CloneGui.IgnoreGuiInset = true
CloneGui.DisplayOrder = 10000
CloneGui.Enabled = false

local CloneButton = Instance.new("ImageButton")
CloneButton.Name = "CloneTool"
CloneButton.Size = UDim2.fromOffset(56.316, 56.316)
CloneButton.Position = UDim2.new(0, 8, 1, 0)
CloneButton.AnchorPoint = Vector2.new(0, 1)
CloneButton.BackgroundColor3 = Color3.fromRGB(255, 142, 142)
CloneButton.BackgroundTransparency = 0
CloneButton.BorderSizePixel = 0
CloneButton.Image = ""
CloneButton.AutoButtonColor = true
CloneButton.Active = true
CloneButton.Selectable = true
CloneButton.ZIndex = 1
CloneButton.Parent = CloneGui

local ButtonCorner = Instance.new("UICorner")
ButtonCorner.CornerRadius = UDim.new(0, 10)
ButtonCorner.Parent = CloneButton

local ButtonAspect = Instance.new("UIAspectRatioConstraint")
ButtonAspect.AspectRatio = 1
ButtonAspect.DominantAxis = Enum.DominantAxis.Width
ButtonAspect.Parent = CloneButton

local DropShadow = Instance.new("ImageLabel")
DropShadow.Name = "DropShadow"
DropShadow.Size = UDim2.new(1, 10, 1, 10)
DropShadow.Position = UDim2.new(0.5, 1, 0.5, 1)
DropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
DropShadow.BackgroundTransparency = 1
DropShadow.Image = "rbxassetid://6865151684"
DropShadow.ImageColor3 = Color3.new(0, 0, 0)
DropShadow.ImageTransparency = 0.2
DropShadow.ScaleType = Enum.ScaleType.Slice
DropShadow.ZIndex = 0
DropShadow.Parent = CloneButton

local TutStroke = Instance.new("UIStroke")
TutStroke.Name = "TutStroke"
TutStroke.Color = Color3.fromRGB(101, 255, 98)
TutStroke.Thickness = 1
TutStroke.Transparency = 0
TutStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
TutStroke.Enabled = false
TutStroke.Parent = CloneButton

local ToolImage = Instance.new("ImageLabel")
ToolImage.Name = "ToolImage"
ToolImage.Size = UDim2.fromScale(0.8, 0.8)
ToolImage.Position = UDim2.fromScale(0.495607, 0.50257)
ToolImage.AnchorPoint = Vector2.new(0.5, 0.5)
ToolImage.BackgroundTransparency = 1
ToolImage.Image = "rbxassetid://12365668909"
ToolImage.ImageRectOffset = Vector2.new(360, 0)
ToolImage.ImageRectSize = Vector2.new(72, 72)
ToolImage.ImageColor3 = Color3.new(1, 1, 1)
ToolImage.ImageTransparency = 0
ToolImage.ScaleType = Enum.ScaleType.Fit
ToolImage.ZIndex = 2
ToolImage.Parent = CloneButton

local ButtonText = Instance.new("TextLabel")
ButtonText.Name = "TextLabel"
ButtonText.Size = UDim2.fromScale(1, 1)
ButtonText.Position = UDim2.fromScale(0, 0)
ButtonText.BackgroundTransparency = 1
ButtonText.Text = "CLONE"
ButtonText.TextColor3 = Color3.new(0, 0, 0)
ButtonText.TextSize = 14
ButtonText.TextScaled = true
ButtonText.Font = Enum.Font.GothamBold
ButtonText.TextXAlignment = Enum.TextXAlignment.Center
ButtonText.TextYAlignment = Enum.TextYAlignment.Center
ButtonText.ZIndex = 2
ButtonText.Parent = CloneButton

CloneGui.Parent = GuiParent

--==================================================
-- TEMPLATE / BLOCK HELPERS
--==================================================

local function GetModelRef(model)
    if not model then return nil end
    return model:FindFirstChild("ColorPart")
        or model:FindFirstChild("MouseFilterPart")
        or model:FindFirstChildWhichIsA("BasePart", true)
end

local function FindTemplate(name)
    if Env.CPT_Utils and type(Env.CPT_Utils.findBlockInRS) == "function" then
        local ok, result = pcall(Env.CPT_Utils.findBlockInRS, name)
        if ok and result then return result end
    end

    local categories = {"Basic", "Decoration", "Events", "Items", "Lights", "Links"}
    local blocks = RS:FindFirstChild("Blocks")
    if blocks then
        for _, category in ipairs(categories) do
            local folder = blocks:FindFirstChild(category)
            local item = folder and folder:FindFirstChild(name)
            if item then return item:FindFirstChild(name) or item end
        end
    end

    local npcs = RS:FindFirstChild("BlocksCutscene")
    npcs = npcs and npcs:FindFirstChild("NPCs")
    local npc = npcs and npcs:FindFirstChild(name)
    if npc then return npc:FindFirstChild(name) or npc end
    return nil
end

local function CreateCopy(source)
    local sourceRef = GetModelRef(source)
    if not sourceRef then
        warn("[CloneTool] Source block reference part not found")
        return nil
    end

    local template = FindTemplate(source.Name)
    if not template then
        warn("[CloneTool] Template not found:", source.Name)
        return nil
    end

    local colorPart = source:FindFirstChild("ColorPart")
    local brickColor = colorPart and colorPart.BrickColor or BrickColor.new("Medium stone grey")
    local material = colorPart and colorPart.Material or Enum.Material.Plastic

    local ok, copy = pcall(function()
        return PlaceBlock:InvokeServer(
            template,
            CFrame.new(0, 10000, 0),
            brickColor,
            material
        )
    end)
    if not ok or not copy then
        warn("[CloneTool] PlaceBlock failed:", copy)
        return nil
    end

    local sourcePivot = sourceRef.CFrame
    local moveOk, moveError = pcall(function()
        CommitMove:InvokeServer(copy, sourcePivot)
    end)
    if not moveOk then
        warn("[CloneTool] Initial CommitMove failed:", moveError)
        return nil
    end

    local defaultSize = Vector3.new(4.5, 4.5, 4.5)
    local sourceBase = source:FindFirstChild("Base")
    local sourceColorPart = source:FindFirstChild("ColorPart")
    local copyBase = copy:FindFirstChild("Base")
    local copyColorPart = copy:FindFirstChild("ColorPart")

    -- Thin Wall is a two-part block. Both Base and ColorPart must be resized
    -- or its dimensions may not persist after save/load.
    if sourceBase and sourceColorPart and copyBase and copyColorPart
        and sourceBase:IsA("BasePart") and sourceColorPart:IsA("BasePart")
        and copyBase:IsA("BasePart") and copyColorPart:IsA("BasePart") then
        task.wait(0.05)
        local resizeData = {
            copyBase, sourceBase.CFrame, sourceBase.Size,
            copyColorPart, sourceColorPart.CFrame, sourceColorPart.Size
        }
        local resizeOk, resizeError = pcall(function()
            CommitResize:InvokeServer(copy, resizeData)
        end)
        if not resizeOk then
            warn("[CloneTool] Thin Wall CommitResize failed:", resizeError)
        end
    else
        local size = sourceRef.Size
        if (size - defaultSize).Magnitude > 0.1 then
            task.wait(0.05)
            local copyRef = GetModelRef(copy)
            if copyRef then
                local resizeOk, resizeError = pcall(function()
                    CommitResize:InvokeServer(copy, {copyRef, sourcePivot, size})
                end)
                if not resizeOk then
                    warn("[CloneTool] CommitResize failed:", resizeError)
                end
            end
        end
    end

    return copy
end

--==================================================
-- MAIN MOVE ACTION HANDOFF
--==================================================

local OriginalPlaceBlockAction = ClientState.PlaceBlockAction
local PendingClone
local Cleaned = false
local Connections = {}

local function UpdateButtonVisibility(mode)
    local modeName = tostring(mode):match("([^%.]+)$")
    CloneGui.Enabled = mode == MoveMode or modeName == "Move" or mode == "Move"
end

local function CloneSelectedBlock()
    if Cleaned then return end
    if BuildingMode:Get() ~= MoveMode then return end

    local source = ClientState.SelectedBlock
    if not source or not source.Parent or source.Parent ~= BuildModel then
        warn("[CloneTool] Select a block with Move before cloning")
        return
    end

    local copy = CreateCopy(source)
    if not copy then return end

    PendingClone = copy
    Env.CloneToolPending = copy

    ClientState.SelectedBlock = copy
    BuildingMode:SetMode(MoveMode)
    print("[CloneTool] Clone created and handed to native Move")
end

local function ClonePlaceBlockAction(self, ...)
    if BuildingMode:Get() == MoveMode and PendingClone then
        local pending = PendingClone
        local result = OriginalPlaceBlockAction(self, ...)

        if self.SelectedBlock == pending then
            self.SelectedBlock = nil
        end

        PendingClone = nil
        Env.CloneToolPending = nil
        BuildingMode:SetMode(MoveMode)
        print("[CloneTool] Move committed; clone selection cleared")
        return result
    end

    return OriginalPlaceBlockAction(self, ...)
end

ClientState.PlaceBlockAction = ClonePlaceBlockAction

table.insert(Connections, CloneButton.Activated:Connect(CloneSelectedBlock))
table.insert(Connections, ChangedEvent.Event:Connect(function(mode)
    UpdateButtonVisibility(mode)
end))

UpdateButtonVisibility(BuildingMode:Get())

--==================================================
-- CLEANUP
--==================================================

local function Cleanup()
    if Cleaned then return end
    Cleaned = true

    for _, connection in ipairs(Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(Connections)

    if ClientState.PlaceBlockAction == ClonePlaceBlockAction then
        ClientState.PlaceBlockAction = OriginalPlaceBlockAction
    end

    if PendingClone and ClientState.SelectedBlock == PendingClone then
        ClientState.SelectedBlock = nil
        pcall(function() BuildingMode:SetMode(MoveMode) end)
    end

    PendingClone = nil
    Env.CloneToolPending = nil

    if CloneGui and CloneGui.Parent then
        CloneGui:Destroy()
    end

    if Env.CloneToolCleanup == Cleanup then
        Env.CloneToolCleanup = nil
    end

    print("[CloneTool] Cleanup complete")
end

Env.CloneToolCleanup = Cleanup

print("================================")
print("[CloneTool] Loaded")
print("[CloneTool] Recreated contextual Clone button: READY")
print("[CloneTool] Button visibility: Move mode only")
print("[CloneTool] Native Move selection handoff: READY")
print("[CloneTool] Separate toolbar button / Clone mode: REMOVED")
print("================================")
