--==================================================
-- MULTI RESIZE TEST
-- Isolated prototype. Does not modify production ResizeTool or MultiSelect.
-- Uses native ResizeHandles for the driver block and fans native
-- ResizeParameters:Drag(delta) out to one independent parameter object
-- per additional selected block.
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
local ResizeModeValue = Enumeration.BuildingMode.Resize
local ResizeMode = require(BuildModeFolder:WaitForChild("Modes"):WaitForChild("Resize"))
local ChangedEvent = BuildModeFolder:WaitForChild("Events"):WaitForChild("BuildingModeChanged")
local PlacementLogic = require(BuildModeFolder:WaitForChild("PlacementLogic"))
local BoxSelectionAdornment = require(
    RS:WaitForChild("Packages")
        :WaitForChild("CustomAdornments")
        :WaitForChild("BoxSelectionAdornment")
)

local Env = (getgenv and getgenv()) or _G
if type(Env.MultiResizeTestCleanup) == "function" then
    pcall(Env.MultiResizeTestCleanup)
end

local ClientState
for attempt = 1, 100 do
    for _, object in ipairs(getgc(true)) do
        if type(object) == "table"
            and rawget(object, "ScreenGui") == BuildModeGui
            and rawget(object, "Toolbar")
            and rawget(object, "ResizeHandles") then
            ClientState = object
            break
        end
    end
    if ClientState then break end
    task.wait(0.1)
end

assert(ClientState, "[MultiResizeTest] BuildModeClient not found")
assert(type(ClientState.PlaceBlockAction) == "function", "[MultiResizeTest] PlaceBlockAction unavailable")

local Handles = ClientState.ResizeHandles
local OriginalPlaceBlockAction = ClientState.PlaceBlockAction
local OriginalResizeUpdate = ResizeMode.Update
local OriginalAdornee = Handles._Adornee
local OriginalRawSetAdornee = rawget(Handles, "SetAdornee")
local RealSetAdornee = Handles.SetAdornee
local Placement = PlacementLogic.new()
local AdornmentParent = BuildModeGui:WaitForChild("Frame"):WaitForChild("Adornment")
local CommitResize = RS:WaitForChild("Functions"):WaitForChild("CommitResize")

local moduleTable
local downOk, downConnections = pcall(getconnections, Handles.MouseButton1Down)
assert(downOk and downConnections, "[MultiResizeTest] Cannot inspect native Resize callback")

for _, connection in ipairs(downConnections) do
    local fn = connection.Function
    if type(fn) == "function" then
        for _, value in pairs(debug.getupvalues(fn)) do
            if type(value) == "table"
                and type(rawget(value, "new")) == "function"
                and type(rawget(value, "Drag")) == "function"
                and type(rawget(value, "Reset")) == "function"
                and type(rawget(value, "__index")) == "table" then
                moduleTable = value
                break
            end
        end
    end
    if moduleTable then break end
end
assert(moduleTable, "[MultiResizeTest] Native ResizeParameters module not found")

local ResizeParametersIndex = moduleTable.__index
local OriginalNew = moduleTable.new
local OriginalDrag = ResizeParametersIndex.Drag

local ProxyModel = Instance.new("Model")
ProxyModel.Name = "JustXMultiResizeBounds"
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

local Gui = Instance.new("ScreenGui")
Gui.Name = "JustXPiggyMultiResizeTest"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 10002
Gui.Enabled = false

local Toggle = Instance.new("TextButton")
Toggle.Name = "MultiResizeButton"
Toggle.Size = UDim2.fromOffset(56, 56)
Toggle.Position = UDim2.new(0, 134, 1, 0)
Toggle.AnchorPoint = Vector2.new(0, 1)
Toggle.BackgroundColor3 = Color3.fromRGB(255, 142, 142)
Toggle.BorderSizePixel = 0
Toggle.Text = "MULTI"
Toggle.TextColor3 = Color3.new(0, 0, 0)
Toggle.TextSize = 14
Toggle.Font = Enum.Font.GothamBold
Toggle.Parent = Gui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 10)
ToggleCorner.Parent = Toggle

Gui.Parent = PlayerGui

local Selection = {}
local Outlines = {}
local Connections = {}
local MultiEnabled = false
local DragObjects = {}
local DragActive = false
local DragDriver = nil
local Cleaned = false
local CommitBusy = false

local function IsResizeMode(mode)
    mode = mode or BuildingMode:Get()
    local name = tostring(mode):match("([^%.]+)$")
    return mode == ResizeModeValue or name == "Resize" or mode == "Resize"
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
        outline:SetColor(Color3.fromRGB(255, 127, 0))
        outline:SetThickness(0.1)
        outline:SetAdornee(block)
    end)
    if ok then
        Outlines[block] = outline
    else
        if outline then pcall(function() outline:Destroy() end) end
        warn("[MultiResizeTest] Outline failed:", err)
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

local function SetHandlesAdornee(target)
    pcall(function()
        Handles:SetAdornee(target)
    end)
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
                            half.X * xSign, half.Y * ySign, half.Z * zSign
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
    local center = (minimum + maximum) * 0.5
    local size = maximum - minimum
    ProxyPart.Size = Vector3.new(
        math.max(size.X, 0.1),
        math.max(size.Y, 0.1),
        math.max(size.Z, 0.1)
    )
    ProxyModel:PivotTo(CFrame.new(driverPivot:PointToWorldSpace(center)) * driverPivot.Rotation)
    return true
end

local function GetGroupAdornee()
    if Cleaned or not MultiEnabled or not IsResizeMode() then return nil end
    if #Selection >= 2 and UpdateProxyBounds() then
        return ProxyModel
    elseif #Selection == 1 and IsValidBlock(Selection[1]) then
        return Selection[1]
    end
    return nil
end

local function WrappedResizeUpdate(self, ...)
    local target = GetGroupAdornee()
    if not target then
        return OriginalResizeUpdate(self, ...)
    end

    rawset(Handles, "SetAdornee", function() end)
    local results = table.pack(pcall(OriginalResizeUpdate, self, ...))
    if OriginalRawSetAdornee ~= nil then
        rawset(Handles, "SetAdornee", OriginalRawSetAdornee)
    else
        rawset(Handles, "SetAdornee", nil)
    end

    if not results[1] then
        error(results[2], 0)
    end

    target = GetGroupAdornee()
    if target then
        pcall(RealSetAdornee, Handles, target)
    end
    return table.unpack(results, 2, results.n)
end
ResizeMode.Update = WrappedResizeUpdate

local function GetHoveredBlock()
    local ok, result = pcall(function()
        return Placement:Raycast()
    end)
    if not ok or not result or not result.Instance then return nil end
    local candidate = result.Instance.Parent
    if IsValidBlock(candidate) then return candidate end
    return nil
end

local function ResetSelection()
    MultiEnabled = false
    DragActive = false
    table.clear(DragObjects)
    ClientState.SelectedBlock = nil
    SetHandlesAdornee(nil)

    local blocks = {}
    for block in pairs(Outlines) do
        table.insert(blocks, block)
    end
    for _, block in ipairs(blocks) do
        RemoveOutline(block)
    end
    table.clear(Selection)
    ProxyPart.Size = Vector3.new(1, 1, 1)
    ProxyModel:PivotTo(CFrame.new(0, -10000, 0))
    UpdateButton()
end

local function ToggleBlock(block)
    if not IsValidBlock(block) then return end
    local index = FindIndex(block)
    if index then
        table.remove(Selection, index)
        RemoveOutline(block)
    else
        table.insert(Selection, block)
        CreateOutline(block)
    end

    DragActive = false
    table.clear(DragObjects)

    -- Keep BuildMode's selection state free so the next click can add
    -- another block. The selected block is assigned only for a real drag.
    ClientState.SelectedBlock = nil
    if #Selection == 0 then
        SetHandlesAdornee(nil)
    elseif #Selection >= 2 then
        UpdateProxyBounds()
        SetHandlesAdornee(ProxyModel)
    else
        SetHandlesAdornee(Selection[1])
    end
    UpdateButton()
end

local function MultiResizePlaceBlockAction(self, ...)
    if Cleaned or not MultiEnabled or not IsResizeMode() then
        return OriginalPlaceBlockAction(self, ...)
    end
    ClientState.SelectedBlock = nil
    local block = GetHoveredBlock()
    if block then ToggleBlock(block) end
    return Enum.ContextActionResult.Sink
end

local function GetResizeParts(block)
    local parts = {}
    for _, child in ipairs(block:GetChildren()) do
        if child:IsA("BasePart") then
            table.insert(parts, child)
        end
    end
    return parts
end

-- Native constructor is called once at the start of a resize drag.
-- Keep its driver object unchanged; create one independent object per
-- additional block so same-named parts cannot overwrite bounding-box keys.
moduleTable.new = function(parts, direction, basePart, parameters)
    local nativeObject = OriginalNew(parts, direction, basePart, parameters)
    table.clear(DragObjects)

    if MultiEnabled and IsResizeMode() and #Selection >= 2 and IsValidBlock(basePart:FindFirstAncestorOfClass("Model")) then
        local driver = ClientState.SelectedBlock
        if IsValidBlock(driver) then
            local driverPart = driver.PrimaryPart
            local worldDirection = driverPart.CFrame:VectorToWorldSpace(direction)

            for _, block in ipairs(Selection) do
                if block ~= driver and IsValidBlock(block) then
                    local blockParts = GetResizeParts(block)
                    local blockBasePart = block.PrimaryPart
                    local localDirection = blockBasePart.CFrame:VectorToObjectSpace(worldDirection)
                    local ok, object = pcall(OriginalNew, blockParts, localDirection, blockBasePart, parameters)
                    if ok and object then
                        table.insert(DragObjects, object)
                    else
                        warn("[MultiResizeTest] Could not initialize resize for", block.Name, object)
                    end
                end
            end
        end
    end

    return nativeObject
end

-- The native handler still performs the driver's resize. Mirror the same
-- drag delta through each other block's independent native parameter object.
ResizeParametersIndex.Drag = function(self, delta, ...)
    local result = table.pack(OriginalDrag(self, delta, ...))
    if MultiEnabled and IsResizeMode() and #Selection >= 2 then
        for _, object in ipairs(DragObjects) do
            local ok, err = pcall(OriginalDrag, object, delta)
            if not ok then
                warn("[MultiResizeTest] Group Drag failed:", err)
            end
        end
    end
    return table.unpack(result, 1, result.n)
end

local function CommitOtherBlocks()
    if CommitBusy or not MultiEnabled or #Selection < 2 then return end
    CommitBusy = true
    task.spawn(function()
        local driver = DragDriver
        for _, block in ipairs(Selection) do
            if block ~= driver and IsValidBlock(block) then
                local realParts = {}
                for _, descendant in ipairs(block:GetDescendants()) do
                    if descendant:IsA("BasePart") and descendant.Name ~= "MouseFilterPart" then
                        table.insert(realParts, descendant)
                    end
                end

                if #realParts == 1 then
                    local part = realParts[1]
                    local payload = {part, part.CFrame, part.Size}
                    local ok, err = pcall(function()
                        CommitResize:InvokeServer(block, payload)
                    end)
                    if not ok then
                        warn("[MultiResizeTest] CommitResize failed for", block.Name, err)
                    end
                else
                    warn("[MultiResizeTest] Commit skipped for", block.Name,
                        "- prototype currently expects exactly one non-MouseFilterPart BasePart")
                end
            end
        end
        CommitBusy = false
    end)
end

local function OnResizeDown()
    if not MultiEnabled or #Selection < 2 then return end
    DragActive = true
    DragDriver = Selection[#Selection]
    ClientState.SelectedBlock = DragDriver
end

local function OnResizeUp()
    if not DragActive then return end
    DragActive = false
    task.defer(function()
        task.wait()
        CommitOtherBlocks()
        table.clear(DragObjects)
        DragDriver = nil
        if MultiEnabled and #Selection >= 2 then
            ClientState.SelectedBlock = Selection[#Selection]
            UpdateProxyBounds()
            SetHandlesAdornee(ProxyModel)
        end
    end)
end

table.insert(Connections, Toggle.Activated:Connect(function()
    if not IsResizeMode() then return end
    if MultiEnabled then
        ResetSelection()
    else
        MultiEnabled = true
        ClientState.SelectedBlock = nil
        table.clear(Selection)
        table.clear(DragObjects)
        UpdateButton()
    end
end))

table.insert(Connections, ChangedEvent.Event:Connect(function(mode)
    task.defer(function()
        if not IsResizeMode(mode) then
            ResetSelection()
        end
        Gui.Enabled = IsResizeMode(mode)
    end)
end))

table.insert(Connections, Handles.MouseButton1Down:Connect(OnResizeDown))
table.insert(Connections, Handles.MouseButton1Up:Connect(OnResizeUp))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if Cleaned then return end

    for index = #Selection, 1, -1 do
        local block = Selection[index]
        if not IsValidBlock(block) then
            table.remove(Selection, index)
            RemoveOutline(block)
        elseif not Outlines[block] then
            CreateOutline(block)
        end
    end

    if MultiEnabled and IsResizeMode() then
        if #Selection >= 2 then
            -- Do not occupy SelectedBlock between clicks: BuildMode uses it
            -- to decide whether the next click is a new selection or an action.
            if not DragActive then
                ClientState.SelectedBlock = nil
                UpdateProxyBounds()
                if Handles._Adornee ~= ProxyModel then
                    SetHandlesAdornee(ProxyModel)
                end
            end
        elseif #Selection == 1 then
            ClientState.SelectedBlock = nil
            if Handles._Adornee ~= Selection[1] then
                SetHandlesAdornee(Selection[1])
            end
        else
            ClientState.SelectedBlock = nil
        end
    end
end))

ClientState.PlaceBlockAction = MultiResizePlaceBlockAction
Gui.Enabled = IsResizeMode()
UpdateButton()

local function Cleanup()
    if Cleaned then return end
    Cleaned = true

    for _, connection in ipairs(Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(Connections)

    if ClientState.PlaceBlockAction == MultiResizePlaceBlockAction then
        ClientState.PlaceBlockAction = OriginalPlaceBlockAction
    end
    if ResizeMode.Update == WrappedResizeUpdate then
        ResizeMode.Update = OriginalResizeUpdate
    end
    if moduleTable.new ~= OriginalNew then
        moduleTable.new = OriginalNew
    end
    if ResizeParametersIndex.Drag ~= OriginalDrag then
        ResizeParametersIndex.Drag = OriginalDrag
    end
    if OriginalRawSetAdornee ~= nil then
        rawset(Handles, "SetAdornee", OriginalRawSetAdornee)
    else
        rawset(Handles, "SetAdornee", nil)
    end

    ResetSelection()
    SetHandlesAdornee(
        typeof(OriginalAdornee) == "Instance"
            and OriginalAdornee:IsA("PVInstance")
            and OriginalAdornee.Parent
            and OriginalAdornee
            or nil
    )
    pcall(function() ProxyModel:Destroy() end)
    pcall(function() Gui:Destroy() end)

    if Env.MultiResizeTestCleanup == Cleanup then
        Env.MultiResizeTestCleanup = nil
    end
end

Env.MultiResizeTestCleanup = Cleanup

print("[MultiResizeTest] Loaded. Switch to Resize, press MULTI, select 2 blocks, then drag one resize handle.")
print("[MultiResizeTest] Test blocks with matching orientation first. Commit is enabled only for one real BasePart per block.")
