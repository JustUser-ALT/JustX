--==================================================
-- ROTATE TOOL
-- Native Build Mode Toolbar Integration
-- Piggy Build Mode rotation tool
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")

local BuildModeFolder = RS:WaitForChild("BuildMode")
local ModesFolder = BuildModeFolder:WaitForChild("Modes")
local IconsFolder = BuildModeFolder:WaitForChild("Resources"):WaitForChild("BuildingModeIcon")
local EventsFolder = BuildModeFolder:WaitForChild("Events")
local ChangedEvent = EventsFolder:WaitForChild("BuildingModeChanged")
local ShowHint = RS:WaitForChild("Events"):WaitForChild("ShowHint")

-- Independent hover raycast and outline modules.
local PlacementLogic = require(BuildModeFolder:WaitForChild("PlacementLogic"))
local BoxSelectionAdornment = require(
    RS:WaitForChild("Packages")
        :WaitForChild("CustomAdornments")
        :WaitForChild("BoxSelectionAdornment")
)

local Env = getgenv()

--==================================================
-- CLEANUP PREVIOUS TEST / VISUAL PROTOTYPE
--==================================================

if type(Env.RotateVisualCleanup) == "function" then
    pcall(Env.RotateVisualCleanup)
end

if type(Env.RotateToolCleanup) == "function" then
    pcall(Env.RotateToolCleanup)
end

-- Backward cleanup for the previous test build.
if type(Env.RotateTestCleanup) == "function" then
    pcall(Env.RotateTestCleanup)
end

--==================================================
-- FIND CLIENT STATE
--==================================================

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

    if ClientState then
        break
    end

    task.wait(0.1)
end

assert(ClientState, "[RotateTool] ClientState not found")

--==================================================
-- FIND BUILDING MODE
--==================================================

local BuildingModeModule = BuildModeFolder:WaitForChild("BuildingMode")
local BuildingMode = require(BuildingModeModule)

assert(
    type(BuildingMode.SetMode) == "function",
    "[RotateTool] BuildingMode.SetMode missing"
)


--==================================================
-- FIND ENUMERATION
--==================================================

local Enumeration = require(BuildModeFolder:WaitForChild("Common"):WaitForChild("Enumeration"))
assert(type(Enumeration) == "table" and Enumeration.BuildingMode, "[RotateTool] Enumeration module invalid")

local BuildingModeEnum = Enumeration.BuildingMode
local EnumItems = rawget(BuildingModeEnum, "__items")
local EnumOrdered = rawget(BuildingModeEnum, "__ordered")

assert(type(EnumItems) == "table", "[RotateTool] Enum items table not found")
assert(type(EnumOrdered) == "table", "[RotateTool] Enum ordered table not found")

local RotateEnum = rawget(EnumItems, "Rotate")
local CreatedEnum = false

if not RotateEnum then
    RotateEnum = {
        Name = "Rotate",
        Value = 9,
        EnumerationType = "BuildingMode"
    }

    setmetatable(RotateEnum, {
        __tostring = function(self)
            return string.format("Enumeration.%s.%s", self.EnumerationType, self.Name)
        end
    })

    rawset(EnumItems, "Rotate", RotateEnum)
    table.insert(EnumOrdered, RotateEnum)
    CreatedEnum = true
end


--==================================================
-- NATIVE PLACE-BLOCK TITLE
-- BuildModeClient's native title table is local to its event callback.
-- SetTitle is applied after the native BuildingModeChanged listeners.
--==================================================

local TitlePatchReady = true

--==================================================
-- REGISTER ROTATE ICON
--==================================================

local RotateIcon = IconsFolder:FindFirstChild("Rotate")
local CreatedIcon = false

if not RotateIcon then
    RotateIcon = IconsFolder:WaitForChild("Move"):Clone()
    RotateIcon.Name = "Rotate"
    RotateIcon.Parent = IconsFolder
    CreatedIcon = true
end

--==================================================
-- FIND RENDER LOOP MODES
--==================================================

local RenderModes

for _, connection in ipairs(getconnections(RunService.RenderStepped)) do
    local fn = connection.Function

    if type(fn) == "function" then
        local success, upvalues = pcall(debug.getupvalues, fn)

        if success and type(upvalues) == "table" then
            for _, value in pairs(upvalues) do
                if type(value) == "table"
                and rawget(value, "Move")
                and rawget(value, "Resize")
                and rawget(value, "Select")
                and rawget(value, "ColorPick") then
                    RenderModes = value
                    break
                end
            end
        end
    end

    if RenderModes then
        break
    end
end

assert(RenderModes, "[RotateTool] RenderLoop modes table not found")

-- Rotation gizmo adapted from the second game's RotateDragger.
-- Native HandleAdornment instances replace the old Drawing circles/lines.
local BuildModel = workspace:WaitForChild("BuildModel")
local Camera = workspace.CurrentCamera
local VERSION = "V1.8"
local Steps = type(Env.JustXPiggyToolSteps) == "table" and Env.JustXPiggyToolSteps or {}
Env.JustXPiggyToolSteps = Steps
local RotationStep = tonumber(Steps.Rotate) or 0.1
Steps.Rotate = RotationStep

local AxisColors = {
    X = Color3.new(1, 0, 0),
    Y = Color3.new(0, 1, 0),
    Z = Color3.new(0, 0, 1)
}

local HandleDefinitions = {
    {Name = "Right", Axis = "X", Direction = Vector3.new(0, 0, 1)},
    {Name = "Left", Axis = "X", Direction = Vector3.new(0, 0, -1)},
    {Name = "Up", Axis = "Y", Direction = Vector3.new(1, 0, 0)},
    {Name = "Down", Axis = "Y", Direction = Vector3.new(-1, 0, 0)},
    {Name = "Back", Axis = "Z", Direction = Vector3.new(0, 1, 0)},
    {Name = "Front", Axis = "Z", Direction = Vector3.new(0, -1, 0)}
}

local StepGui = Instance.new("ScreenGui")
StepGui.Name = "JustXRotateStepSettings"
StepGui.ResetOnSpawn = false
StepGui.IgnoreGuiInset = true
StepGui.DisplayOrder = 10000
StepGui.Enabled = false

local StepInput = Instance.new("TextBox")
StepInput.Name = "StepInput"
StepInput.Size = UDim2.fromOffset(55, 25)
StepInput.Position = UDim2.new(1, -65, 0.46, 0)
StepInput.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
StepInput.BorderSizePixel = 0
StepInput.TextColor3 = Color3.new(1, 1, 1)
StepInput.Text = tostring(RotationStep)
StepInput.PlaceholderText = tostring(RotationStep)
StepInput.Font = Enum.Font.Gotham
StepInput.TextSize = 12
StepInput.ClearTextOnFocus = false
StepInput.Parent = StepGui

local StepCorner = Instance.new("UICorner")
StepCorner.CornerRadius = UDim.new(0, 5)
StepCorner.Parent = StepInput

local GuiParent
pcall(function()
    if type(gethui) == "function" then
        GuiParent = gethui()
    end
end)
StepGui.Parent = GuiParent or PlayerGui

StepInput.FocusLost:Connect(function()
    local value = tonumber(StepInput.Text)
    if not value then
        StepInput.Text = tostring(RotationStep)
        return
    end

    RotationStep = math.clamp(value, 0.1, 10)
    Steps.Rotate = RotationStep
    StepInput.Text = tostring(RotationStep)
end)

local VersionLabel = Drawing.new("Text")
VersionLabel.Text = VERSION
VersionLabel.Size = 16
VersionLabel.Position = Vector2.new(12, 12)
VersionLabel.Color = Color3.fromRGB(255, 255, 255)
VersionLabel.Outline = true
VersionLabel.Center = false
VersionLabel.Visible = true
pcall(function() VersionLabel.ZIndex = 100 end)

local AdornmentFolder = Instance.new("Folder")
AdornmentFolder.Name = "JustXRotateGizmo"
AdornmentFolder.Parent = BuildModeGui:WaitForChild("Frame"):WaitForChild("Adornment")

local Handles = {}
local Rings = {}
local ActiveHandle
local ActiveInputType
local IsDragging = false
local DragStartPivot
local DragAxisWorld
local DragOrigin
local DragPreviousVector
local TotalDragAngle = 0
local CurrentPointer
local CurrentModel
local DragConnection

local TouchScale = {
    None = 0.6,
    Hovering = 0.8,
    Dragging = 0.7
}

local MouseScale = {
    None = 0.4,
    Hovering = 0.6,
    Dragging = 0.5
}

local CurrentScale = UserInputService:GetLastInputType() == Enum.UserInputType.Touch
    and TouchScale or MouseScale

local HandleConnections = {}
local DragConnection

local InputTypeConnection = UserInputService.LastInputTypeChanged:Connect(function(inputType)
    if inputType == Enum.UserInputType.Touch then
        CurrentScale = TouchScale
    elseif inputType == Enum.UserInputType.MouseMovement
        or inputType == Enum.UserInputType.MouseButton1 then
        CurrentScale = MouseScale
    end
end)

local function GetCameraScale(worldPosition)
    Camera = workspace.CurrentCamera
    if not Camera then
        return 0
    end

    local distance = (Camera.CFrame.Position - worldPosition).Magnitude
    return math.sin(math.rad(Camera.FieldOfView)) * distance * 0.05
end

-- One cylinder ring per local axis, as in the source RotateDragger.
for _, axis in ipairs({"X", "Y", "Z"}) do
    local ring = Instance.new("CylinderHandleAdornment")
    ring.Name = axis
    ring.Adornee = workspace.Terrain
    ring.AlwaysOnTop = true
    ring.ZIndex = 4
    ring.Color3 = AxisColors[axis]
    ring.Transparency = 0.5
    ring.Visible = false
    ring.Parent = AdornmentFolder
    Rings[axis] = ring
end

-- Six spherical grab points, two on the plane perpendicular to each axis.
for index, definition in ipairs(HandleDefinitions) do
    local sphere = Instance.new("SphereHandleAdornment")
    sphere.Name = definition.Name
    sphere.Adornee = workspace.Terrain
    sphere.AlwaysOnTop = true
    sphere.ZIndex = 5
    sphere.Color3 = AxisColors[definition.Axis]
    sphere.Transparency = 0.5
    sphere.Visible = false
    sphere.Parent = AdornmentFolder

    Handles[index] = {
        Definition = definition,
        Sphere = sphere,
        ScreenPosition = Vector2.zero,
        WorldPosition = Vector3.zero,
        Visible = false,
        Hovering = false
    }
end

local function HideRotationRing()
    for _, ring in pairs(Rings) do
        ring.Visible = false
    end
end

local function UpdateRotationRing()
    -- Ring transforms are updated together with the six grab points in UpdateGizmo.
end

local function HideHandles()
    for _, handle in ipairs(Handles) do
        handle.Visible = false
        handle.Sphere.Visible = false
    end
    HideRotationRing()
end

local function GetModelSize(model)
    if model:IsA("Model") then
        local _, size = model:GetBoundingBox()
        return size
    elseif model:IsA("BasePart") then
        return model.Size
    end

    return Vector3.new(4, 4, 4)
end

local function SetModel(model)
    CurrentModel = model

    if not model then
        HideHandles()
        return
    end

    local size = GetModelSize(model)
end

local function GetMousePositionOnPlane(position, origin, normal)
    Camera = workspace.CurrentCamera
    if not Camera then
        return nil
    end

    local ray = Camera:ScreenPointToRay(position.X, position.Y)
    local denominator = ray.Direction:Dot(normal)

    if math.abs(denominator) < 1e-5 then
        return nil
    end

    local distance = (origin - ray.Origin):Dot(normal) / denominator
    if distance < 0 then
        return nil
    end

    local worldPoint = ray.Origin + ray.Direction * distance
    local vector = worldPoint - origin
    vector = vector - normal * vector:Dot(normal)

    if vector.Magnitude < 1e-5 then
        return nil
    end

    return vector.Unit
end

local function GetAxisVector(pivot, axis)
    if axis == "X" then
        return pivot.RightVector
    elseif axis == "Y" then
        return pivot.UpVector
    end

    return -pivot.LookVector
end

local function ApplyDrag(position)
    if not IsDragging
        or not DragStartPivot
        or not DragAxisWorld
        or not DragOrigin
        or not DragPreviousVector
        or not CurrentModel
        or not CurrentModel.Parent then
        return
    end

    local currentVector = GetMousePositionOnPlane(position, DragOrigin, DragAxisWorld)
    if not currentVector then
        return
    end

    -- Signed angle around the selected axis: atan2(axis · (previous × current), previous · current).
    -- This is equivalent to the source's acos(dot) + cross-product sign calculation.
    local sine = DragAxisWorld:Dot(DragPreviousVector:Cross(currentVector))
    local cosine = math.clamp(DragPreviousVector:Dot(currentVector), -1, 1)
    local delta = math.atan2(sine, cosine)

    TotalDragAngle = TotalDragAngle + delta
    DragPreviousVector = currentVector

    local stepRadians = math.rad(RotationStep)
    local snappedAngle = math.round(TotalDragAngle / stepRadians) * stepRadians
    local rotation = CFrame.fromAxisAngle(DragAxisWorld, snappedAngle)

    CurrentModel:PivotTo(
        CFrame.new(DragOrigin)
            * rotation
            * CFrame.new(-DragOrigin)
            * DragStartPivot
    )
end

local function BeginDrag(handleIndex, position)
    if not CurrentModel or not CurrentModel.Parent then
        return false
    end

    local definition = Handles[handleIndex].Definition
    DragStartPivot = CurrentModel:GetPivot()
    DragOrigin = DragStartPivot.Position
    DragAxisWorld = GetAxisVector(DragStartPivot, definition.Axis).Unit

    -- The source dragger derives the pointer vector from the ray/rotation-plane intersection.
    DragPreviousVector = GetMousePositionOnPlane(position, DragOrigin, DragAxisWorld)
    if not DragPreviousVector then
        DragStartPivot = nil
        DragOrigin = nil
        DragAxisWorld = nil
        return false
    end

    TotalDragAngle = 0
    IsDragging = true
    UpdateRotationRing()
    return true
end

local function FinishDrag()
    if IsDragging and CurrentModel and CurrentModel.Parent then
        local functionsFolder = RS:FindFirstChild("Functions")
        local commitMove = functionsFolder and functionsFolder:FindFirstChild("CommitMove")

        if commitMove then
            local ok, err = pcall(function()
                commitMove:InvokeServer(CurrentModel, CurrentModel:GetPivot())
            end)
            if not ok then
                warn("[RotateTool] CommitMove failed: " .. tostring(err))
            end
        else
            warn("[RotateTool] RS.Functions.CommitMove not found")
        end
    end

    IsDragging = false
    HideRotationRing()
    DragStartPivot = nil
    DragAxisWorld = nil
    DragOrigin = nil
    DragPreviousVector = nil
    TotalDragAngle = 0
end

local function SetActiveHandle(index)
    ActiveHandle = index
    local activeAxis = index and Handles[index].Definition.Axis or nil

    for handleIndex, handle in ipairs(Handles) do
        local active = handleIndex == index
        handle.Sphere.Transparency = active and 0.2 or 0.5
        handle.Sphere.Color3 = AxisColors[handle.Definition.Axis]
    end

    for axis, ring in pairs(Rings) do
        ring.Transparency = axis == activeAxis and 0.2 or 0.5
    end
end

local function GetPointerPosition()
    local position = UserInputService:GetMouseLocation()
    return Vector2.new(position.X, position.Y)
end

local function StartHandleDrag(handleIndex)
    if IsDragging or not CurrentModel or not CurrentModel.Parent
        or UserInputService:GetFocusedTextBox() then
        return false
    end

    local lastInputType = UserInputService:GetLastInputType()
    ActiveInputType = lastInputType == Enum.UserInputType.Touch
        and Enum.UserInputType.Touch
        or Enum.UserInputType.MouseButton1

    CurrentPointer = GetPointerPosition()
    SetActiveHandle(handleIndex)

    if not BeginDrag(handleIndex, CurrentPointer) then
        SetActiveHandle(nil)
        ActiveInputType = nil
        CurrentPointer = nil
        return false
    end

    -- Match the original RotateDragger: movement is tracked only during a drag.
    DragConnection = UserInputService.InputChanged:Connect(function(inputObject)
        if not IsDragging then
            return
        end

        if ActiveInputType == Enum.UserInputType.Touch
            and inputObject.UserInputType == Enum.UserInputType.Touch then
            CurrentPointer = GetPointerPosition()
        elseif ActiveInputType == Enum.UserInputType.MouseButton1
            and inputObject.UserInputType == Enum.UserInputType.MouseMovement then
            CurrentPointer = GetPointerPosition()
        end
    end)

    return true
end

local function EndHandleDrag()
    if DragConnection then
        DragConnection:Disconnect()
        DragConnection = nil
    end

    if IsDragging then
        FinishDrag()
    end

    SetActiveHandle(nil)
    ActiveInputType = nil
    CurrentPointer = nil
end

for index, handle in ipairs(Handles) do
    local sphere = handle.Sphere

    table.insert(HandleConnections, sphere.MouseEnter:Connect(function()
        handle.Hovering = true
    end))

    table.insert(HandleConnections, sphere.MouseLeave:Connect(function()
        handle.Hovering = false
    end))

    table.insert(HandleConnections, sphere.MouseButton1Down:Connect(function()
        StartHandleDrag(index)
    end))
end

local InputEndedConnection = UserInputService.InputEnded:Connect(function(inputObject)
    if ActiveInputType == Enum.UserInputType.Touch
        and inputObject.UserInputType == Enum.UserInputType.Touch then
        EndHandleDrag()
    elseif ActiveInputType == Enum.UserInputType.MouseButton1
        and inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
        EndHandleDrag()
    elseif inputObject.KeyCode == Enum.KeyCode.ButtonR2 then
        EndHandleDrag()
    end
end)

local WindowFocusReleasedConnection = UserInputService.WindowFocusReleased:Connect(function()
    if IsDragging then
        EndHandleDrag()
    end
end)

local function UpdateGizmo()
    Camera = workspace.CurrentCamera
    if not CurrentModel or not CurrentModel.Parent or not Camera then
        HideHandles()
        return
    end

    local pivot = CurrentModel:GetPivot()
    local size = GetModelSize(CurrentModel)
    local ringRadius = math.max(size.X, size.Y, size.Z)
    local sphereOffset = GetCameraScale(pivot.Position)
    local ringHeight = math.max(sphereOffset * 0.1, 0.001)

    local ringRotations = {
        X = CFrame.Angles(0, math.rad(90), 0),
        Y = CFrame.Angles(math.rad(90), 0, 0),
        Z = CFrame.Angles(0, 0, math.rad(90))
    }

    for axis, ring in pairs(Rings) do
        ring.Adornee = workspace.Terrain
        ring.CFrame = pivot * ringRotations[axis]
        ring.Radius = ringRadius
        ring.InnerRadius = math.max(ringRadius - ringHeight, 0)
        ring.Height = ringHeight
        ring.Visible = true
    end

    local pointer = CurrentPointer
    for _, handle in ipairs(Handles) do
        local definition = handle.Definition
        local localOffset = definition.Direction * (ringRadius + sphereOffset)
        local worldCFrame = pivot * CFrame.new(localOffset)
        local worldPosition = worldCFrame.Position
        local screenPosition, onScreen = Camera:WorldToScreenPoint(worldPosition)
        local visible = onScreen and screenPosition.Z > 0

        handle.Visible = visible
        handle.WorldPosition = worldPosition
        handle.ScreenPosition = Vector2.new(screenPosition.X, screenPosition.Y)

        local sphere = handle.Sphere
        sphere.Adornee = workspace.Terrain
        sphere.CFrame = worldCFrame
        sphere.Visible = visible

        local stateScale = CurrentScale.None
        local transparency = 0.5

        if IsDragging and ActiveHandle then
            if Handles[ActiveHandle].Definition.Axis == definition.Axis then
                stateScale = CurrentScale.Dragging
                transparency = 0.2
            end
        elseif (CurrentScale == MouseScale and handle.Hovering)
            or (CurrentScale == TouchScale and pointer and visible
                and (handle.ScreenPosition - pointer).Magnitude <= HitRadius) then
            stateScale = CurrentScale.Hovering
            transparency = 0.4
        end

        sphere.Radius = math.max(sphereOffset * stateScale, 0.025)
        sphere.Transparency = transparency
    end

    local hoveredAxes = {}
    if CurrentScale == MouseScale then
        for _, handle in ipairs(Handles) do
            if handle.Hovering then
                hoveredAxes[handle.Definition.Axis] = true
            end
        end
    elseif CurrentScale == TouchScale and pointer then
        for _, handle in ipairs(Handles) do
            if handle.Visible
                and (handle.ScreenPosition - pointer).Magnitude <= HitRadius then
                hoveredAxes[handle.Definition.Axis] = true
            end
        end
    end

    for axis, ring in pairs(Rings) do
        if IsDragging and ActiveHandle and Handles[ActiveHandle].Definition.Axis == axis then
            ring.Transparency = 0.2
        elseif hoveredAxes[axis] then
            ring.Transparency = 0.4
        else
            ring.Transparency = 0.5
        end
    end
end

local function UpdateSelectedModel(selected)
    if typeof(selected) ~= "Instance"
        or not selected:IsDescendantOf(BuildModel) then
        SetModel(nil)
        return
    end

    if selected ~= CurrentModel then
        SetModel(selected)
    end
end

--==================================================
-- ROTATE MODE
-- Selected block, six-axis rotation gizmo, drag handling and save commit.
--==================================================

local RotateMode = {
    Initialized = false,
    Active = false,
    ClientState = nil,
    Placement = nil,
    Outline = nil,
    Target = nil
}

function RotateMode:Init(clientState)
    self.ClientState = clientState

    self.Placement = PlacementLogic.new()
    self.Outline = BoxSelectionAdornment.new()

    local adornmentParent = BuildModeGui:WaitForChild("Frame"):WaitForChild("Adornment")

    self.Outline:SetParent(adornmentParent)
    self.Outline:SetColor(Color3.fromRGB(170, 85, 255))
    self.Outline:SetThickness(0.03)
    self.Outline:SetAdornee(nil)

    self.Initialized = true
    end

function RotateMode:Enter(clientState)
    self.ClientState = clientState or self.ClientState
    self.Active = true
    self.Target = nil

    if self.Outline then
        pcall(function()
            self.Outline:SetAdornee(nil)
        end)
    end

    end

function RotateMode:Exit()
    if IsDragging then
        FinishDrag()
    end
    SetActiveHandle(nil)
    ActiveInputType = nil
    CurrentPointer = nil
    SetModel(nil)
    HideHandles()
    HideRotationRing()

    self.Active = false
    self.Target = nil

    if self.Outline then
        pcall(function()
            self.Outline:SetAdornee(nil)
        end)
    end

    if self.ClientState then
        pcall(function()
            self.ClientState.BoxSelection:SetAdornee(nil)
            self.ClientState.BoxSelection:SetColor(Color3.new(0, 0, 1))
            self.ClientState.MoveHandles:SetAdornee(nil)
            self.ClientState.SelectedBlock = nil
        end)
    end

    end

function RotateMode:Update(dt, clientState)
    if not self.Active or not self.Placement or not self.Outline then
        return
    end

    self.ClientState = clientState or self.ClientState

    local state = self.ClientState
    local boxSelection = state and state.BoxSelection
    if not state or not boxSelection then
        return
    end

    -- RenderLoop clears BoxSelection before every mode Update.
    -- Re-apply the selected outline here, after that clear.
    local selected = state.SelectedBlock
    if selected and selected.Parent then
        boxSelection:SetColor(Color3.fromRGB(170, 85, 255))
        boxSelection:SetAdornee(selected)
        self.Outline:SetAdornee(nil)
        self.Target = nil

        UpdateSelectedModel(selected)

        if IsDragging and CurrentPointer then
            ApplyDrag(CurrentPointer)
        end
        UpdateGizmo()
        return
    end

    -- No selected block: fully reset the gizmo, including stale touch/handle state.
    if IsDragging then
        FinishDrag()
    end
    SetActiveHandle(nil)
    ActiveInputType = nil
    CurrentPointer = nil
    SetModel(nil)
    HideHandles()
    HideRotationRing()
    boxSelection:SetAdornee(nil)

    local raycastOk, result = pcall(function()
        return self.Placement:Raycast()
    end)

    local block = nil

    if raycastOk and result and result.Instance then
        local candidate = result.Instance.Parent
        local buildModel = workspace:FindFirstChild("BuildModel")

        if candidate
            and candidate:IsA("Model")
            and buildModel
            and candidate.Parent == buildModel then
            block = candidate
        end
    end

    if block ~= self.Target then
        self.Target = block

        local outlineOk, outlineError = pcall(function()
            self.Outline:SetAdornee(block)
        end)

        if not outlineOk then
            warn("[RotateTool] Hover outline error:", outlineError)
        else
                    end
    end
end

function RotateMode:Action(clientState)
    if not self.Active then
        return Enum.ContextActionResult.Sink
    end

    self.ClientState = clientState or self.ClientState

    local state = self.ClientState
    if not state or not self.Placement then
        return Enum.ContextActionResult.Sink
    end

    local raycastOk, result = pcall(function()
        return self.Placement:Raycast()
    end)

    if not raycastOk or not result or not result.Instance then
        state.SelectedBlock = nil
                return Enum.ContextActionResult.Sink
    end

    local block = result.Instance.Parent
    local buildModel = workspace:FindFirstChild("BuildModel")

    if not block or not buildModel or block.Parent ~= buildModel then
                return Enum.ContextActionResult.Sink
    end

    if state.SelectedBlock == block then
        state.SelectedBlock = nil
        if IsDragging then
            FinishDrag()
        end
        SetActiveHandle(nil)
        ActiveInputType = nil
        CurrentPointer = nil
        SetModel(nil)
        HideHandles()
        HideRotationRing()
            else
        state.SelectedBlock = block
            end

    return Enum.ContextActionResult.Sink
end

function RotateMode:Destroy()
    if IsDragging then
        FinishDrag()
    end
    if InputTypeConnection then
        InputTypeConnection:Disconnect()
        InputTypeConnection = nil
    end
    if InputEndedConnection then
        InputEndedConnection:Disconnect()
        InputEndedConnection = nil
    end
    if WindowFocusReleasedConnection then
        WindowFocusReleasedConnection:Disconnect()
        WindowFocusReleasedConnection = nil
    end
    for _, connection in ipairs(HandleConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(HandleConnections)
    HideHandles()
    HideRotationRing()
    pcall(function() AdornmentFolder:Destroy() end)
    pcall(function() VersionLabel:Remove() end)
    pcall(function() StepGui:Destroy() end)

    self.Active = false
    self.Target = nil

    if self.Outline then
        pcall(function()
            self.Outline:Destroy()
        end)
        self.Outline = nil
    end

    self.Placement = nil
    self.Initialized = false
end

local PreviousRenderMode = rawget(RenderModes, "Rotate")
RenderModes.Rotate = RotateMode
RotateMode:Init(ClientState)

--==================================================
-- ROUTE THE MAIN PLACE-BLOCK BUTTON TO ROTATE
-- Preserve the original dispatcher for every native mode.
--==================================================

local OriginalPlaceBlockAction = ClientState.PlaceBlockAction
assert(
    type(OriginalPlaceBlockAction) == "function",
    "[RotateTool] ClientState.PlaceBlockAction missing"
)

local function RotatePlaceBlockAction(self, ...)
    local currentMode = BuildingMode:Get()

    if currentMode and currentMode.Name == "Rotate" then
        return RotateMode:Action(self, ...)
    end

    return OriginalPlaceBlockAction(self, ...)
end

ClientState.PlaceBlockAction = RotatePlaceBlockAction

--==================================================
-- FIND NATIVE TOOLBAR
--==================================================

local Toolbar = ClientState.Toolbar
local BuildingToolbar = Toolbar and Toolbar.BuildingModeToolbar

assert(BuildingToolbar, "[RotateTool] BuildingModeToolbar not found")

local Frame = BuildingToolbar.Instance
local Slots = BuildingToolbar.Slots

assert(Frame and Slots, "[RotateTool] Toolbar structure invalid")
assert(Slots[6] and Slots[6].Instance, "[RotateTool] Move button not found")

--==================================================
-- CREATE ROTATE BUTTON
--==================================================

local Button = Slots[6].Instance:Clone()
Button.Name = "RotateButton"
Button.LayoutOrder = 7
Button.Position = UDim2.fromOffset(444, 0)

local ButtonIcon = Button:FindFirstChild("Move")
if ButtonIcon then
    ButtonIcon.Name = "Rotate"
end

local OriginalFrameSize = Frame.Size
local OriginalSlot7 = Slots[7]

Button.Parent = Frame
Frame.Size = UDim2.fromOffset(524, 80)

Slots[7] = {
    Instance = Button
}

--==================================================
-- CONNECTIONS / NATIVE SELECTION BEHAVIOR
--==================================================

local Connections = {}

local function Connect(connection)
    table.insert(Connections, connection)
    return connection
end

local StepModeConnection = Connect(ChangedEvent.Event:Connect(function(modeName)
    StepGui.Enabled = modeName == "Rotate"
end))
StepGui.Enabled = BuildingMode:Get() == RotateEnum

local SelectedModeName = "rotate tool"

Connect(Button.Activated:Connect(function()
    
    -- Match the native toolbar button's feedback.
    ShowHint:Fire(string.format("Selected %s", SelectedModeName))

    -- Select the custom enum mode.
    BuildingMode:SetMode(RotateEnum)

    -- Match the native toolbar button's close/cleanup behavior.
    Frame.Visible = false
    CAS:UnbindAction("pick_building_mode")

    if type(BuildingToolbar.HideInputIcons) == "function" then
        BuildingToolbar:HideInputIcons()
    end

    end))

Connect(ChangedEvent.Event:Connect(function(modeName)
    if modeName == "Rotate" then
                if not RotateMode.Active then
            RotateMode:Enter(ClientState)
        end

        -- BuildModeClient has no native title for the custom enum item.
        -- Defer until its listener has attempted the native SetTitle call.
        task.defer(function()
            if not Cleaned and BuildingMode:Get() == RotateEnum then
                local ok, err = pcall(function()
                    CAS:SetTitle("place_block", "Rotate")
                end)
                if not ok then
                    warn("[RotateTool] Could not set main button title:", err)
                end
            end
        end)
    elseif RotateMode.Active then
                RotateMode:Exit()
    end
end))

--==================================================
-- CLEANUP
--==================================================

local Cleaned = false

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

    if RotateMode.Active then
        pcall(function()
            RotateMode:Exit(ClientState)
        end)
    end

    pcall(function()
        RotateMode:Destroy()
    end)

    if BuildingMode:Get() == RotateEnum then
        pcall(function()
            BuildingMode:SetMode(Enumeration.BuildingMode.None)
        end)
    end

    if rawget(RenderModes, "Rotate") == RotateMode then
        RenderModes.Rotate = PreviousRenderMode
    end

    if ClientState.PlaceBlockAction == RotatePlaceBlockAction then
        ClientState.PlaceBlockAction = OriginalPlaceBlockAction
    end

    if Slots[7] and Slots[7].Instance == Button then
        Slots[7] = OriginalSlot7
    end

    pcall(function()
        Button:Destroy()
    end)

    pcall(function()
        Frame.Size = OriginalFrameSize
    end)

    if CreatedEnum and rawget(EnumItems, "Rotate") == RotateEnum then
        rawset(EnumItems, "Rotate", nil)

        for index, item in ipairs(EnumOrdered) do
            if item == RotateEnum then
                table.remove(EnumOrdered, index)
                break
            end
        end
    end

    if CreatedIcon and RotateIcon and RotateIcon.Parent then
        RotateIcon:Destroy()
    end

    if Env.RotateToolCleanup == Cleanup then
        Env.RotateToolCleanup = nil
    end
    if Env.RotateTestCleanup == Cleanup then
        Env.RotateTestCleanup = nil
    end
end

--==================================================
-- GLOBAL REFERENCES
--==================================================

Env.RotateToolCleanup = Cleanup
Env.RotateTestCleanup = Cleanup
Env.RotateToolMode = RotateMode
Env.RotateToolEnum = RotateEnum

