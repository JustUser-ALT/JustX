--==================================================
-- MULTI SELECT
-- Production multi-selection with native group Move handles.
-- Uses the native MoveHandles to drag the active block,
-- then mirrors the same world-space delta to the other
-- selected blocks and commits them individually.
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
local Enumeration = require(BuildModeFolder:WaitForChild("Common"):WaitForChild("Enumeration"))
local MoveModeValue = Enumeration.BuildingMode.Move
local MoveMode = require(BuildModeFolder:WaitForChild("Modes"):WaitForChild("Move"))
local ChangedEvent = BuildModeFolder:WaitForChild("Events"):WaitForChild("BuildingModeChanged")
local PlacementLogic = require(BuildModeFolder:WaitForChild("PlacementLogic"))
local BoxSelectionAdornment = require(
    RS:WaitForChild("Packages")
        :WaitForChild("CustomAdornments")
        :WaitForChild("BoxSelectionAdornment")
)

local Env = (getgenv and getgenv()) or _G

if type(Env.MultiSelectCleanup) == "function" then
    pcall(Env.MultiSelectCleanup)
end
if type(Env.MultiSelectTestCleanup) == "function" then
    pcall(Env.MultiSelectTestCleanup)
end

local ClientState
assert(type(getgc) == "function", "[MultiSelect] getgc unavailable")

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

assert(ClientState, "[MultiSelect] BuildModeClient not found")
assert(type(ClientState.PlaceBlockAction) == "function", "[MultiSelect] PlaceBlockAction unavailable")
assert(ClientState.MoveHandles, "[MultiSelect] MoveHandles unavailable")

local OriginalPlaceBlockAction = ClientState.PlaceBlockAction
local MoveHandles = ClientState.MoveHandles
local Placement = PlacementLogic.new()
local AdornmentParent = BuildModeGui:WaitForChild("Frame"):WaitForChild("Adornment")
local OriginalMoveAdornee = MoveHandles._Adornee

-- A local-only PVInstance used exclusively to position the native handles.
-- Its orientation follows the active driver; its bounds cover the whole group.
local ProxyModel = Instance.new("Model")
ProxyModel.Name = "JustXMultiMoveBounds"
local ProxyPart = Instance.new("Part")
ProxyPart.Name = "GroupBounds"
ProxyPart.Anchored = true
ProxyPart.Transparency = 1
ProxyPart.Size = Vector3.new(1, 1, 1)
ProxyPart.CanCollide = false
ProxyPart.CanTouch = false
ProxyPart.CanQuery = false
ProxyPart.CastShadow = false
ProxyPart.Locked = true
ProxyPart.Parent = ProxyModel
ProxyModel.PrimaryPart = ProxyPart
ProxyModel.Parent = workspace

-- PlayerGui is the reliable parent in this executor context.
-- MultiSelect is contextual UI, not a native toolbar slot.
local GuiParent = PlayerGui

local Gui = Instance.new("ScreenGui")
Gui.Name = "JustXPiggyMultiSelect"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 10001
Gui.Enabled = false

local Toggle = Instance.new("ImageButton")
Toggle.Name = "MultiSelectButton"
Toggle.Size = UDim2.fromOffset(56.316, 56.316)
Toggle.Position = UDim2.new(0, 72, 1, 0)
Toggle.AnchorPoint = Vector2.new(0, 1)
Toggle.BackgroundColor3 = Color3.fromRGB(255, 142, 142)
Toggle.BackgroundTransparency = 0
Toggle.BorderSizePixel = 0
Toggle.Image = ""
Toggle.AutoButtonColor = true
Toggle.Active = true
Toggle.Selectable = true
Toggle.ZIndex = 1
Toggle.Parent = Gui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 10)
ToggleCorner.Parent = Toggle

local ToggleAspect = Instance.new("UIAspectRatioConstraint")
ToggleAspect.AspectRatio = 1
ToggleAspect.DominantAxis = Enum.DominantAxis.Width
ToggleAspect.Parent = Toggle

local ToggleShadow = Instance.new("ImageLabel")
ToggleShadow.Name = "DropShadow"
ToggleShadow.Size = UDim2.new(1, 10, 1, 10)
ToggleShadow.Position = UDim2.new(0.5, 1, 0.5, 1)
ToggleShadow.AnchorPoint = Vector2.new(0.5, 0.5)
ToggleShadow.BackgroundTransparency = 1
ToggleShadow.Image = "rbxassetid://6865151684"
ToggleShadow.ImageColor3 = Color3.new(0, 0, 0)
ToggleShadow.ImageTransparency = 0.2
ToggleShadow.ScaleType = Enum.ScaleType.Slice
ToggleShadow.ZIndex = 0
ToggleShadow.Parent = Toggle

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Name = "TutStroke"
ToggleStroke.Color = Color3.fromRGB(101, 255, 98)
ToggleStroke.Thickness = 1
ToggleStroke.Transparency = 0
ToggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ToggleStroke.Enabled = false
ToggleStroke.Parent = Toggle

local ToggleLabel = Instance.new("TextLabel")
ToggleLabel.Name = "TextLabel"
ToggleLabel.Size = UDim2.fromScale(1, 1)
ToggleLabel.BackgroundTransparency = 1
ToggleLabel.Text = "MULTI"
ToggleLabel.TextColor3 = Color3.new(0, 0, 0)
ToggleLabel.TextSize = 14
ToggleLabel.TextScaled = true
ToggleLabel.Font = Enum.Font.GothamBold
ToggleLabel.TextXAlignment = Enum.TextXAlignment.Center
ToggleLabel.TextYAlignment = Enum.TextYAlignment.Center
ToggleLabel.ZIndex = 2
ToggleLabel.Parent = Toggle

Gui.Parent = GuiParent

local Selection = {}
local Outlines = {}
local Connections = {}
local MultiEnabled = false
local GroupArmed = false
local Cleaned = false
local DragSession = nil
local CommitBusy = false

local OriginalMoveUpdate = MoveMode.Update
local OriginalRawSetAdornee = rawget(MoveHandles, "SetAdornee")
local RealSetAdornee = MoveHandles.SetAdornee

local IsMoveMode
local IsValidBlock

local function GetMultiHandlesAdornee()
    if Cleaned or not MultiEnabled or not IsMoveMode() then
        return nil
    end

    if GroupArmed then
        -- Group handles are visualized from the current selection, not
        -- ClientState.SelectedBlock. That state stays free during selection
        -- and is assigned only when the user starts dragging the handles.
        local driver = Selection[#Selection]
        if IsValidBlock(driver) and ProxyModel.Parent == workspace then
            return ProxyModel
        end
        return nil
    end

    -- A lone selected block must not occupy ClientState.SelectedBlock:
    -- that state is consumed by BuildMode's main action and prevents
    -- the next block from being selected. Keep only the visual handle.
    if #Selection == 1 and IsValidBlock(Selection[1]) then
        return Selection[1]
    end

    return nil
end

local function WrappedMoveUpdate(self, ...)
    local target = GetMultiHandlesAdornee()
    if not target then
        return OriginalMoveUpdate(self, ...)
    end

    -- Let native Move.Update refresh its internal state while preventing
    -- it from replacing the selection's handle target.
    rawset(MoveHandles, "SetAdornee", function() end)

    local results = table.pack(pcall(OriginalMoveUpdate, self, ...))

    if OriginalRawSetAdornee ~= nil then
        rawset(MoveHandles, "SetAdornee", OriginalRawSetAdornee)
    else
        rawset(MoveHandles, "SetAdornee", nil)
    end

    if not results[1] then
        warn("[MultiSelect] Native Move.Update failed:", results[2])
        error(results[2], 0)
    end

    target = GetMultiHandlesAdornee()
    if target then
        local ok, err = pcall(RealSetAdornee, MoveHandles, target)
        if not ok then
            warn("[MultiSelect] Handle positioning failed:", err)
        end
    end

    return table.unpack(results, 2, results.n)
end

MoveMode.Update = WrappedMoveUpdate

local function ModeName()
    local mode = BuildingMode:Get()
    if mode == nil then return "" end
    local ok, name = pcall(function() return mode.Name end)
    if ok and type(name) == "string" then return name end
    return tostring(mode):match("([^%.]+)$") or tostring(mode)
end

IsMoveMode = function(mode)
    mode = mode or BuildingMode:Get()
    local modeName = tostring(mode):match("([^%.]+)$")
    return mode == MoveModeValue or modeName == "Move" or mode == "Move"
end

IsValidBlock = function(block)
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

local function UpdateControls()
    -- Keep the short label inside the original Clone-sized button.
    -- The background color already communicates the enabled state.
    ToggleLabel.Text = "MULTI"
    Toggle.BackgroundColor3 = MultiEnabled
        and Color3.fromRGB(97, 255, 115)
        or Color3.fromRGB(255, 142, 142)
end

local function CreateOutline(block)
    if not IsValidBlock(block) then return false end

    local existing = Outlines[block]
    if existing then
        local ok, parent = pcall(function()
            return existing.Parent
        end)
        if ok and parent then
            return true
        end
        Outlines[block] = nil
    end

    local outline
    local ok, err = pcall(function()
        outline = BoxSelectionAdornment.new()
        assert(outline, "BoxSelectionAdornment.new() returned nil")
        outline:SetParent(AdornmentParent)
        outline:SetColor(Color3.fromRGB(0, 0, 255))
        outline:SetThickness(0.1)
        outline:SetAdornee(block)
    end)

    if not ok then
        if outline then
            pcall(function()
                outline:SetAdornee(nil)
                outline:Destroy()
            end)
        end
        warn("[MultiSelect] Outline creation failed for", block:GetFullName(), err)
        return false
    end

    Outlines[block] = outline
    return true
end

local function RemoveOutline(block)
    local outline = Outlines[block]
    if not outline then return end
    Outlines[block] = nil
    pcall(function()
        outline:SetAdornee(nil)
        outline:Destroy()
    end)
end

local function SetDriver()
    -- Do not occupy BuildMode's SelectedBlock while selecting.
    -- BeginGroupDrag assigns the driver only for the duration of a drag.
    ClientState.SelectedBlock = nil
end

local function UpdateProxyBounds()
    local driver = Selection[#Selection]
    if not IsValidBlock(driver) then return false end

    local driverPivot = driver:GetPivot()
    local minimum = Vector3.new(math.huge, math.huge, math.huge)
    local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
    local found = false

    for _, block in ipairs(Selection) do
        if IsValidBlock(block) then
            local boxCFrame, boxSize = block:GetBoundingBox()
            local half = boxSize * 0.5

            for xSign = -1, 1, 2 do
                for ySign = -1, 1, 2 do
                    for zSign = -1, 1, 2 do
                        local corner = boxCFrame:PointToWorldSpace(Vector3.new(
                            half.X * xSign,
                            half.Y * ySign,
                            half.Z * zSign
                        ))
                        local localCorner = driverPivot:PointToObjectSpace(corner)
                        minimum = Vector3.new(
                            math.min(minimum.X, localCorner.X),
                            math.min(minimum.Y, localCorner.Y),
                            math.min(minimum.Z, localCorner.Z)
                        )
                        maximum = Vector3.new(
                            math.max(maximum.X, localCorner.X),
                            math.max(maximum.Y, localCorner.Y),
                            math.max(maximum.Z, localCorner.Z)
                        )
                        found = true
                    end
                end
            end
        end
    end

    if not found then return false end

    local localCenter = (minimum + maximum) * 0.5
    local boundsSize = maximum - minimum
    local worldCenter = driverPivot:PointToWorldSpace(localCenter)

    ProxyPart.Size = Vector3.new(
        math.max(boundsSize.X, 0.1),
        math.max(boundsSize.Y, 0.1),
        math.max(boundsSize.Z, 0.1)
    )
    ProxyModel:PivotTo(CFrame.new(worldCenter) * driverPivot.Rotation)
    return true
end

local function SetMoveHandlesAdornee(adornee)
    local ok, err = pcall(function()
        MoveHandles:SetAdornee(adornee)
    end)
    if not ok then
        warn("[MultiSelect] SetAdornee failed:", err)
    end
    return ok
end

local function ArmGroup()
    if #Selection < 2 then return false end

    SetDriver()
    if not UpdateProxyBounds() then
        GroupArmed = false
        ClientState.SelectedBlock = nil
        warn("[MultiSelect] Could not calculate group bounds")
        return false
    end

    GroupArmed = true
    local ok = SetMoveHandlesAdornee(ProxyModel)
    if not ok then
        GroupArmed = false
        ClientState.SelectedBlock = nil
        return false
    end

    print("[MultiSelect] Group handles appeared automatically after main action")
    return true
end

local function ClearSelection()
    -- Snapshot keys first: RemoveOutline mutates Outlines while iterating.
    local outlinedBlocks = {}
    for block in pairs(Outlines) do
        table.insert(outlinedBlocks, block)
    end

    for _, block in ipairs(outlinedBlocks) do
        RemoveOutline(block)
    end

    table.clear(Selection)
    UpdateControls()
end

local function ResetMultiSelect(reason)
    -- Full reset removes the group and exits selection mode.
    GroupArmed = false
    DragSession = nil
    MultiEnabled = false

    SetMoveHandlesAdornee(nil)
    ClientState.SelectedBlock = nil
    ClearSelection()

    -- Keep the invisible proxy in a harmless neutral state for a later run.
    ProxyPart.Size = Vector3.new(1, 1, 1)
    ProxyModel:PivotTo(CFrame.new(0, -10000, 0))

    UpdateControls()
    print("[MultiSelect] Full MultiSelect reset:", reason or "manual")
end

local function ToggleBlock(block)
    if not IsValidBlock(block) then return end

    local index = FindIndex(block)
    if index then
        table.remove(Selection, index)
        RemoveOutline(block)
        print("[MultiSelect] Removed:", block:GetFullName())
    else
        table.insert(Selection, block)
        local outlined = CreateOutline(block)
        print("[MultiSelect] Added:", block:GetFullName(), "outline:", outlined)
    end

    -- One selected block uses the native single-block Move handles.
    -- Two or more blocks automatically switch to the group proxy handles.
    if #Selection >= 2 then
        local armed = ArmGroup()
        if not armed then
            GroupArmed = false
            DragSession = nil
            SetMoveHandlesAdornee(nil)
            ClientState.SelectedBlock = nil
        end
    elseif #Selection == 1 then
        GroupArmed = false
        DragSession = nil
        -- Do not set ClientState.SelectedBlock here. The main BuildMode
        -- action must remain free to add the next block to the selection.
        ClientState.SelectedBlock = nil
        SetMoveHandlesAdornee(Selection[1])
    else
        GroupArmed = false
        DragSession = nil
        SetMoveHandlesAdornee(nil)
        ClientState.SelectedBlock = nil
    end
    UpdateControls()
end

local function GetHoveredBlock()
    local ok, result = pcall(function()
        return Placement:Raycast()
    end)
    if not ok or not result or not result.Instance then return nil end

    local candidate = result.Instance.Parent
    if IsValidBlock(candidate) then return candidate end
    return nil
end

local function MultiMovePlaceBlockAction(self, ...)
    if Cleaned or not MultiEnabled or not IsMoveMode() then
        return OriginalPlaceBlockAction(self, ...)
    end

    -- The main BuildMode action always edits the selection, even while
    -- group handles are visible. ToggleBlock will re-arm the correct handles
    -- after adding or removing the block.
    -- A previous group driver must never block the next selection click.
    ClientState.SelectedBlock = nil
    local block = GetHoveredBlock()
    if block then
        ToggleBlock(block)
    else
        print("[MultiSelect] Click ignored: no BuildModel block under pointer")
    end
    return Enum.ContextActionResult.Sink
end

local function ApplyGroupDelta()
    local session = DragSession
    if not session or not IsValidBlock(session.driver) then return end

    local ok, currentPivot = pcall(function()
        return session.driver:GetPivot()
    end)
    if not ok then return end

    local delta = currentPivot * session.driverStart:Inverse()
    for block, startPivot in pairs(session.starts) do
        if block ~= session.driver and IsValidBlock(block) then
            pcall(function()
                block:PivotTo(delta * startPivot)
            end)
        end
    end

    if GroupArmed then
        UpdateProxyBounds()
    end
end

local function FindCommitMove()
    local functionsFolder = RS:FindFirstChild("Functions")
    if not functionsFolder then
        return nil
    end

    local remote = functionsFolder:FindFirstChild("CommitMove")
    if remote and remote:IsA("RemoteFunction") then
        return remote
    end

    return nil
end

local function CommitGroupOthers()
    if CommitBusy then return end
    local session = DragSession
    DragSession = nil
    if not session then return end

    local remote = FindCommitMove()
    if not remote then
        warn("[MultiSelect] CommitMove RemoteFunction not found; other blocks were moved locally only")
        return
    end

    CommitBusy = true
    task.spawn(function()
        for block in pairs(session.starts) do
            if block ~= session.driver and IsValidBlock(block) then
                local ok, err = pcall(function()
                    remote:InvokeServer(block, block:GetPivot())
                end)
                if not ok then
                    warn("[MultiSelect] CommitMove failed for", block:GetFullName(), err)
                end
            end
        end
        CommitBusy = false
        print("[MultiSelect] Group commit pass finished")
    end)
end

local function BeginGroupDrag()
    if not MultiEnabled or not GroupArmed or not IsMoveMode() or #Selection < 2 then
        DragSession = nil
        return
    end

    local driver = ClientState.SelectedBlock
    if not IsValidBlock(driver) or not FindIndex(driver) then
        driver = Selection[#Selection]
        if not IsValidBlock(driver) then return end
        ClientState.SelectedBlock = driver
    end

    local starts = {}
    for _, block in ipairs(Selection) do
        if IsValidBlock(block) then
            starts[block] = block:GetPivot()
        end
    end

    if #Selection < 2 then return end

    DragSession = {
        driver = driver,
        driverStart = driver:GetPivot(),
        starts = starts
    }
    print("[MultiSelect] Group drag started; driver:", driver:GetFullName())
end

local function UpdateVisibility(mode)
    local visible = IsMoveMode(mode)
    Gui.Enabled = visible
    Toggle.Visible = visible
end

table.insert(Connections, Toggle.Activated:Connect(function()
    if not IsMoveMode() then return end

    if MultiEnabled then
        ResetMultiSelect("Multi button")
    else
        MultiEnabled = true
        GroupArmed = false
        DragSession = nil
        ClientState.SelectedBlock = nil
        UpdateControls()
        print("[MultiSelect] Selection mode enabled")
    end
end))

table.insert(Connections, ChangedEvent.Event:Connect(function(mode)
    task.defer(function()
        if not IsMoveMode(mode) then
            ResetMultiSelect("mode changed")
        end
        UpdateVisibility(mode)
    end)
end))

table.insert(Connections, MoveHandles.MouseButton1Down:Connect(BeginGroupDrag))

table.insert(Connections, MoveHandles.MouseDrag:Connect(function()
    if DragSession then
        ApplyGroupDelta()
    end
end))

table.insert(Connections, MoveHandles.MouseButton1Up:Connect(function()
    if not DragSession then return end
    ApplyGroupDelta()
    task.defer(function()
        task.wait()
        CommitGroupOthers()
        if MultiEnabled and GroupArmed then
            ClientState.SelectedBlock = nil
        end
    end)
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if Cleaned then return end

    for index = #Selection, 1, -1 do
        local block = Selection[index]
        if not IsValidBlock(block) then
            table.remove(Selection, index)
            RemoveOutline(block)
        elseif not Outlines[block] then
            -- Selection and its visual adornment are deliberately tracked
            -- separately. Retry any outline that failed during the click.
            CreateOutline(block)
        end
    end

    if MultiEnabled and IsMoveMode() then
        if DragSession then
            ApplyGroupDelta()
        end
        if GroupArmed then
            -- Keep the main BuildMode action free to select more blocks.
            -- The driver is assigned only in BeginGroupDrag().
            if not DragSession and ClientState.SelectedBlock ~= nil then
                ClientState.SelectedBlock = nil
            end
            UpdateProxyBounds()
        elseif #Selection == 1 then
            -- Keep the single-block handles visible without occupying
            -- BuildMode's SelectedBlock state.
            if ClientState.SelectedBlock ~= nil then
                ClientState.SelectedBlock = nil
            end
            local selected = Selection[1]
            if IsValidBlock(selected) and MoveHandles._Adornee ~= selected then
                SetMoveHandlesAdornee(selected)
            end
        elseif ClientState.SelectedBlock ~= nil then
            ClientState.SelectedBlock = nil
        end
    end
    UpdateControls()
end))

ClientState.PlaceBlockAction = MultiMovePlaceBlockAction
UpdateVisibility()
UpdateControls()

local function Cleanup()
    if Cleaned then return end
    Cleaned = true
    DragSession = nil

    for _, connection in ipairs(Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(Connections)

    if ClientState.PlaceBlockAction == MultiMovePlaceBlockAction then
        ClientState.PlaceBlockAction = OriginalPlaceBlockAction
    end

    if MoveMode.Update == WrappedMoveUpdate then
        MoveMode.Update = OriginalMoveUpdate
    end

    if OriginalRawSetAdornee ~= nil then
        rawset(MoveHandles, "SetAdornee", OriginalRawSetAdornee)
    else
        rawset(MoveHandles, "SetAdornee", nil)
    end

    ClearSelection()
    SetMoveHandlesAdornee(
        typeof(OriginalMoveAdornee) == "Instance"
            and OriginalMoveAdornee:IsA("PVInstance")
            and OriginalMoveAdornee.Parent
            and OriginalMoveAdornee
            or nil
    )
    pcall(function() ProxyModel:Destroy() end)
    pcall(function() Gui:Destroy() end)

    if Env.MultiSelectCleanup == Cleanup then
        Env.MultiSelectCleanup = nil
    end
    print("[MultiSelect] Cleanup complete")
end

Env.MultiSelectCleanup = Cleanup

print("================================")
print("[MultiSelect] Loaded")
print("[MultiSelect] Group handle centering hook installed")
print("[MultiSelect] Select Move mode and enable MULTI")
print("[MultiSelect] One selected block shows native single-block Move handles")
print("[MultiSelect] Group handles appear automatically when the second block is selected")
print("[MultiSelect] Keep using the main BuildMode action to add or remove any number of blocks")
print("[MultiSelect] Tap MULTI once to enable; tap again to disable and clear all selection")
print("[MultiSelect] Drag the native Move arrows to move the group")
print("[MultiSelect] Other blocks are committed individually on release")
print("[MultiSelect] Use MultiSelectCleanup() to unload")
print("================================")
