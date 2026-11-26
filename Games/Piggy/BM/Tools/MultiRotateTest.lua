--==================================================
-- MULTI ROTATE TEST
-- Isolated group-rotation layer over the working RotateTool.
-- Keeps the original rings, drag math and touch-camera lock.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Env = (getgenv and getgenv()) or _G
if type(Env.MultiRotateTestCleanup) == "function" then
    pcall(Env.MultiRotateTestCleanup)
end

local RotateMode = Env.RotateToolMode
assert(type(RotateMode) == "table" and RotateMode.Active ~= nil,
    "[MultiRotateTest] Load RotateTool.lua first and switch to Rotate mode once")

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

local ClientState
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
    if ClientState then break end
    task.wait(0.1)
end
assert(ClientState, "[MultiRotateTest] BuildModeClient not found")

local OriginalPlaceBlockAction = ClientState.PlaceBlockAction
local OriginalRotateUpdate = RotateMode.Update
local PreviousPivotOverride = Env.RotateToolPivotOverride
local Placement = PlacementLogic.new()
local AdornmentParent = BuildModeGui:WaitForChild("Frame"):WaitForChild("Adornment")
local CommitMove = RS:WaitForChild("Functions"):WaitForChild("CommitMove")

local Gui = Instance.new("ScreenGui")
Gui.Name = "JustXPiggyMultiRotateTest"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 10003
Gui.Enabled = false

local Toggle = Instance.new("TextButton")
Toggle.Name = "MultiRotateButton"
Toggle.Size = UDim2.fromOffset(56, 56)
Toggle.Position = UDim2.new(0, 196, 1, 0)
Toggle.AnchorPoint = Vector2.new(0, 1)
Toggle.BackgroundColor3 = Color3.fromRGB(255, 142, 142)
Toggle.BorderSizePixel = 0
Toggle.Text = "MULTI"
Toggle.TextColor3 = Color3.new(0, 0, 0)
Toggle.TextSize = 14
Toggle.Font = Enum.Font.GothamBold
Toggle.Parent = Gui
local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 10)
Corner.Parent = Toggle
Gui.Parent = PlayerGui

local Selection = {}
local Outlines = {}
local Connections = {}
local MultiEnabled = false
local Cleaned = false
local CommitBusy = false
local GroupChanged = false
local LastDriverPivot

local function IsRotateMode(mode)
    mode = mode or BuildingMode:Get()
    local name = tostring(mode):match("([^%.]+)$")
    return mode == "Rotate" or name == "Rotate"
        or (type(mode) == "table" and mode.Name == "Rotate")
end

local function IsValidBlock(block)
    return typeof(block) == "Instance"
        and block:IsA("Model")
        and block.Parent == BuildModel
        and block.PrimaryPart ~= nil
end

local function FindIndex(block)
    for index, selected in ipairs(Selection) do
        if selected == block then return index end
    end
end

local function UpdateButton()
    Toggle.BackgroundColor3 = MultiEnabled
        and Color3.fromRGB(97, 255, 115)
        or Color3.fromRGB(255, 142, 142)
end

local function CreateOutline(block)
    if not IsValidBlock(block) or Outlines[block] then return end
    local outline
    local ok, err = pcall(function()
        outline = BoxSelectionAdornment.new()
        outline:SetParent(AdornmentParent)
        outline:SetColor(Color3.fromRGB(170, 85, 255))
        outline:SetThickness(0.1)
        outline:SetAdornee(block)
    end)
    if ok then
        Outlines[block] = outline
    else
        if outline then pcall(function() outline:Destroy() end) end
        warn("[MultiRotateTest] Outline failed:", err)
    end
end

local function RemoveOutline(block)
    local outline = Outlines[block]
    Outlines[block] = nil
    if outline then
        pcall(function()
            outline:SetAdornee(nil)
            outline:Destroy()
        end)
    end
end

local function ClearOutlines()
    local blocks = {}
    for block in pairs(Outlines) do table.insert(blocks, block) end
    for _, block in ipairs(blocks) do RemoveOutline(block) end
end

local function GetHoveredBlock()
    local ok, result = pcall(function() return Placement:Raycast() end)
    if not ok or not result or not result.Instance then return nil end
    local candidate = result.Instance.Parent
    if IsValidBlock(candidate) then return candidate end
    return nil
end

local function GetDriver()
    local driver = Selection[#Selection]
    if IsValidBlock(driver) then return driver end
    return nil
end

-- Calculate a world-space bounding box for the complete selection. The
-- gizmo orientation follows the real driver, but its origin is the group center.
local function GetGroupGizmoTransform(model)
    if not MultiEnabled or #Selection < 2 or model ~= GetDriver() then
        return nil
    end

    local driverPivot = model:GetPivot()
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

    -- Measure every selected block in the driver's local orientation.
    -- This avoids mixing a world-aligned AABB with a rotated gizmo.
    for _, block in ipairs(Selection) do
        if IsValidBlock(block) then
            local boxCFrame, boxSize = block:GetBoundingBox()
            local half = boxSize * 0.5

            for x = -1, 1, 2 do
                for y = -1, 1, 2 do
                    for z = -1, 1, 2 do
                        local worldCorner = (boxCFrame * CFrame.new(
                            half.X * x, half.Y * y, half.Z * z
                        )).Position
                        local localCorner = driverPivot:PointToObjectSpace(worldCorner)

                        minX = math.min(minX, localCorner.X)
                        minY = math.min(minY, localCorner.Y)
                        minZ = math.min(minZ, localCorner.Z)
                        maxX = math.max(maxX, localCorner.X)
                        maxY = math.max(maxY, localCorner.Y)
                        maxZ = math.max(maxZ, localCorner.Z)
                    end
                end
            end
        end
    end

    if minX == math.huge then return nil end

    local localCenter = Vector3.new(
        (minX + maxX) * 0.5,
        (minY + maxY) * 0.5,
        (minZ + maxZ) * 0.5
    )
    local size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
    local center = driverPivot:PointToWorldSpace(localCenter)
    local orientation = driverPivot - driverPivot.Position

    return CFrame.new(center) * orientation, size
end

Env.RotateToolPivotOverride = GetGroupGizmoTransform

local function ResetDriverPivot()
    local driver = GetDriver()
    LastDriverPivot = driver and driver:GetPivot() or nil
end

local function ApplyDriverDelta()
    local driver = GetDriver()
    if not driver then
        LastDriverPivot = nil
        return
    end

    local current = driver:GetPivot()
    if not LastDriverPivot then
        LastDriverPivot = current
        return
    end

    local delta = current * LastDriverPivot:Inverse()
    local moved = (current.Position - LastDriverPivot.Position).Magnitude > 1e-5
        or current.LookVector:Dot(LastDriverPivot.LookVector) < 0.999999

    if moved then
        GroupChanged = true
        for _, block in ipairs(Selection) do
            if block ~= driver and IsValidBlock(block) then
                pcall(function()
                    block:PivotTo(delta * block:GetPivot())
                end)
            end
        end
    end

    LastDriverPivot = current
end

local function CommitGroup()
    if CommitBusy or not GroupChanged then return end
    CommitBusy = true
    GroupChanged = false

    local driver = GetDriver()
    local blocks = {}
    for _, block in ipairs(Selection) do
        if block ~= driver and IsValidBlock(block) then
            table.insert(blocks, block)
        end
    end

    task.spawn(function()
        for _, block in ipairs(blocks) do
            if IsValidBlock(block) then
                local ok, err = pcall(function()
                    CommitMove:InvokeServer(block, block:GetPivot())
                end)
                if not ok then
                    warn("[MultiRotateTest] CommitMove failed for", block.Name, err)
                end
            end
        end
        CommitBusy = false
    end)
end

local function UpdateHoverOutline()
    if not RotateMode.Outline then return end

    local hovered = GetHoveredBlock()
    if hovered and FindIndex(hovered) then
        hovered = nil
    end

    pcall(function()
        RotateMode.Outline:SetAdornee(hovered)
    end)
end

local function RefreshSelection()
    for index = #Selection, 1, -1 do
        local block = Selection[index]
        if not IsValidBlock(block) then
            table.remove(Selection, index)
            RemoveOutline(block)
        else
            local outline = Outlines[block]
            if not outline then
                CreateOutline(block)
                outline = Outlines[block]
            end
            if outline then
                pcall(function()
                    outline:SetAdornee(nil)
                    outline:SetAdornee(block)
                end)
            end
        end
    end

    ResetDriverPivot()
end

local function ToggleBlock(block)
    local index = FindIndex(block)
    if index then
        table.remove(Selection, index)
        RemoveOutline(block)
    else
        table.insert(Selection, block)
        CreateOutline(block)
    end
    RefreshSelection()
end

local function ResetSelection()
    CommitGroup()
    MultiEnabled = false
    table.clear(Selection)
    ClearOutlines()
    ClientState.SelectedBlock = nil
    LastDriverPivot = nil
    UpdateButton()
end

local function MultiRotatePlaceBlockAction(self, ...)
    if Cleaned or not MultiEnabled or not IsRotateMode() then
        return OriginalPlaceBlockAction(self, ...)
    end

    ClientState.SelectedBlock = nil
    local block = GetHoveredBlock()
    if block then
        ToggleBlock(block)
    else
        ResetSelection()
    end
    return Enum.ContextActionResult.Sink
end

ClientState.PlaceBlockAction = MultiRotatePlaceBlockAction

-- Keep the original RotateTool gizmo and touch handling attached to a real
-- selected block. Its pivot delta is mirrored to the other selected blocks.
local function WrappedRotateUpdate(self, dt, clientState)
    if Cleaned or not MultiEnabled or not IsRotateMode() then
        return OriginalRotateUpdate(self, dt, clientState)
    end

    RefreshSelection()
    local driver = GetDriver()
    local state = clientState or ClientState
    if not driver then
        state.SelectedBlock = nil
        return OriginalRotateUpdate(self, dt, state)
    end

    state.SelectedBlock = driver
    local results = table.pack(pcall(OriginalRotateUpdate, self, dt, state))
    ApplyDriverDelta()

    if not results[1] then
        error(results[2], 0)
    end

    UpdateHoverOutline()
    return table.unpack(results, 2, results.n)
end
RotateMode.Update = WrappedRotateUpdate

table.insert(Connections, Toggle.Activated:Connect(function()
    if not IsRotateMode() then return end
    if MultiEnabled then
        ResetSelection()
    else
        MultiEnabled = true
        table.clear(Selection)
        LastDriverPivot = nil
        ClientState.SelectedBlock = nil
        UpdateButton()
    end
end))

table.insert(Connections, ChangedEvent.Event:Connect(function(mode)
    task.defer(function()
        if not IsRotateMode(mode) and MultiEnabled then
            ResetSelection()
        end
        Gui.Enabled = IsRotateMode(mode)
    end)
end))

-- RotateTool's own InputEnded handler finishes its drag first. Defer our
-- group commit until its final proxy movement has been mirrored.
table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
    if not MultiEnabled or not GroupChanged then return end
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1
        or input.KeyCode == Enum.KeyCode.ButtonR2 then
        task.defer(function()
            task.wait()
            ApplyDriverDelta()
            CommitGroup()
            RefreshSelection()
        end)
    end
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if Cleaned or not MultiEnabled or not IsRotateMode() then return end
    RefreshSelection()
end))

local function Cleanup()
    if Cleaned then return end
    Cleaned = true
    CommitGroup()
    for _, connection in ipairs(Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(Connections)
    if ClientState.PlaceBlockAction == MultiRotatePlaceBlockAction then
        ClientState.PlaceBlockAction = OriginalPlaceBlockAction
    end
    if RotateMode.Update == WrappedRotateUpdate then
        RotateMode.Update = OriginalRotateUpdate
    end
    if Env.RotateToolPivotOverride == GetGroupGizmoTransform then
        Env.RotateToolPivotOverride = PreviousPivotOverride
    end
    ClearOutlines()
    table.clear(Selection)
    ClientState.SelectedBlock = nil
    LastDriverPivot = nil
    pcall(function() Gui:Destroy() end)
    if Env.MultiRotateTestCleanup == Cleanup then
        Env.MultiRotateTestCleanup = nil
    end
end

Env.MultiRotateTestCleanup = Cleanup
print("[MultiRotateTest] Loaded. Switch to Rotate, press MULTI, select 2+ blocks, then drag a rotation handle.")
print("[MultiRotateTest] Prototype only. Test rotation, mobile touch, deselection and save before production integration.")
