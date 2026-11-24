--==================================================
-- ROTATE VISUAL + INTERACTION TEST
-- Standalone test: no Just X Library / no BuildMode toolbar hooks.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local BuildModel = workspace:WaitForChild("BuildModel")

local Env = (getgenv and getgenv()) or _G
if type(Env.RotateVisualTestCleanup) == "function" then
    pcall(Env.RotateVisualTestCleanup)
end

local AXIS_COLORS = {
    X = Color3.fromRGB(255, 75, 75),
    Y = Color3.fromRGB(80, 235, 125),
    Z = Color3.fromRGB(75, 145, 255)
}

local HANDLE_DEFS = {
    {Name = "Right", Axis = "X", Direction = Vector3.new(0, 0, 1)},
    {Name = "Left", Axis = "X", Direction = Vector3.new(0, 0, -1)},
    {Name = "Up", Axis = "Y", Direction = Vector3.new(1, 0, 0)},
    {Name = "Down", Axis = "Y", Direction = Vector3.new(-1, 0, 0)},
    {Name = "Back", Axis = "Z", Direction = Vector3.new(0, 1, 0)},
    {Name = "Front", Axis = "Z", Direction = Vector3.new(0, -1, 0)}
}

local cleaned = false
local selectedModel
local pickMode = true
local dragging = false
local activeHandle
local dragStartPivot
local dragAxis
local dragCenter
local lastAngle
local totalAngle = 0
local angleStep = 1
local currentPointer
local touchInput
local activeInputType
local connections = {}
local handles = {}
local camera = workspace.CurrentCamera

local function track(connection)
    table.insert(connections, connection)
    return connection
end

local function getInset()
    local topLeft = GuiService:GetGuiInset()
    return Vector2.new(topLeft.X, topLeft.Y)
end

local function getPointerPosition(input)
    local p = input.Position
    return Vector2.new(p.X, p.Y)
end

local function getViewportPosition(input)
    return getPointerPosition(input) - getInset()
end

--==================================================
-- TEST UI
--==================================================

local gui = Instance.new("ScreenGui")
gui.Name = "RotateVisualTestUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10020
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(236, 158)
panel.Position = UDim2.new(0, 16, 0.5, -79)
panel.BackgroundColor3 = Color3.fromRGB(25, 27, 33)
panel.BorderSizePixel = 0
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(72, 77, 91)
panelStroke.Thickness = 1
panelStroke.Parent = panel

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, -42, 0, 30)
header.Position = UDim2.fromOffset(11, 3)
header.BackgroundTransparency = 1
header.Text = "ROTATE TEST"
header.TextColor3 = Color3.fromRGB(245, 246, 250)
header.TextSize = 13
header.Font = Enum.Font.GothamBold
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(27, 25)
closeButton.Position = UDim2.new(1, -32, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(55, 58, 68)
closeButton.Text = "×"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextSize = 19
closeButton.Font = Enum.Font.Gotham
closeButton.Parent = panel
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 6)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 29)
status.Position = UDim2.fromOffset(10, 34)
status.BackgroundColor3 = Color3.fromRGB(34, 37, 45)
status.Text = "Tap a block to select it"
status.TextColor3 = Color3.fromRGB(205, 210, 222)
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.TextWrapped = true
status.Parent = panel
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 6)

local pickButton = Instance.new("TextButton")
pickButton.Size = UDim2.fromOffset(102, 30)
pickButton.Position = UDim2.fromOffset(10, 70)
pickButton.BackgroundColor3 = Color3.fromRGB(55, 105, 180)
pickButton.Text = "PICK: ON"
pickButton.TextColor3 = Color3.new(1, 1, 1)
pickButton.TextSize = 11
pickButton.Font = Enum.Font.GothamBold
pickButton.Parent = panel
Instance.new("UICorner", pickButton).CornerRadius = UDim.new(0, 6)

local clearButton = Instance.new("TextButton")
clearButton.Size = UDim2.fromOffset(102, 30)
clearButton.Position = UDim2.fromOffset(120, 70)
clearButton.BackgroundColor3 = Color3.fromRGB(65, 68, 78)
clearButton.Text = "CLEAR"
clearButton.TextColor3 = Color3.new(1, 1, 1)
clearButton.TextSize = 11
clearButton.Font = Enum.Font.GothamBold
clearButton.Parent = panel
Instance.new("UICorner", clearButton).CornerRadius = UDim.new(0, 6)

local stepLabel = Instance.new("TextLabel")
stepLabel.Size = UDim2.fromOffset(94, 26)
stepLabel.Position = UDim2.fromOffset(11, 116)
stepLabel.BackgroundTransparency = 1
stepLabel.Text = "Angle step (°)"
stepLabel.TextColor3 = Color3.fromRGB(190, 195, 207)
stepLabel.TextSize = 11
stepLabel.Font = Enum.Font.Gotham
stepLabel.TextXAlignment = Enum.TextXAlignment.Left
stepLabel.Parent = panel

local stepInput = Instance.new("TextBox")
stepInput.Size = UDim2.fromOffset(72, 26)
stepInput.Position = UDim2.fromOffset(151, 116)
stepInput.BackgroundColor3 = Color3.fromRGB(39, 42, 51)
stepInput.Text = tostring(angleStep)
stepInput.PlaceholderText = "1"
stepInput.TextColor3 = Color3.new(1, 1, 1)
stepInput.TextSize = 11
stepInput.Font = Enum.Font.Gotham
stepInput.ClearTextOnFocus = false
stepInput.Parent = panel
Instance.new("UICorner", stepInput).CornerRadius = UDim.new(0, 6)

local function setStatus(message)
    status.Text = message
end

-- Drag the panel by its header area.
local panelDragging = false
local panelDragStart
local panelStartPosition

track(header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        panelDragging = true
        panelDragStart = input.Position
        panelStartPosition = panel.Position
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if panelDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - panelDragStart
        panel.Position = UDim2.new(
            panelStartPosition.X.Scale,
            panelStartPosition.X.Offset + delta.X,
            panelStartPosition.Y.Scale,
            panelStartPosition.Y.Offset + delta.Y
        )
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        panelDragging = false
    end
end))

--==================================================
-- NATIVE ADORNMENTS
--==================================================

local adornmentFolder = Instance.new("Folder")
adornmentFolder.Name = "RotateVisualTestAdornments"
adornmentFolder.Parent = PlayerGui

for index, definition in ipairs(HANDLE_DEFS) do
    local ring = Instance.new("CylinderHandleAdornment")
    ring.Name = "Ring_" .. definition.Axis
    ring.Adornee = workspace.Terrain
    ring.AlwaysOnTop = true
    ring.ZIndex = 4
    ring.Color3 = AXIS_COLORS[definition.Axis]
    ring.Transparency = 0.48
    ring.Visible = false
    ring.Parent = adornmentFolder

    local sphere = Instance.new("SphereHandleAdornment")
    sphere.Name = "Handle_" .. definition.Name
    sphere.Adornee = workspace.Terrain
    sphere.AlwaysOnTop = true
    sphere.ZIndex = 5
    sphere.Color3 = AXIS_COLORS[definition.Axis]
    sphere.Transparency = 0.35
    sphere.Visible = false
    sphere.Parent = adornmentFolder

    handles[index] = {
        Definition = definition,
        Ring = ring,
        Sphere = sphere,
        ScreenPosition = Vector2.zero,
        Visible = false
    }
end

local function getModelSize(model)
    if model:IsA("Model") then
        local _, size = model:GetBoundingBox()
        return size
    elseif model:IsA("BasePart") then
        return model.Size
    end
    return Vector3.new(4, 4, 4)
end

local function hideHandles()
    for _, handle in ipairs(handles) do
        handle.Visible = false
        handle.Ring.Visible = false
        handle.Sphere.Visible = false
    end
end

local function setSelection(model)
    if model and (not model.Parent or not model:IsDescendantOf(BuildModel)) then
        model = nil
    end

    selectedModel = model
    dragging = false
    activeHandle = nil
    dragStartPivot = nil
    dragAxis = nil
    currentPointer = nil
    touchInput = nil
    activeInputType = nil

    if model then
        setStatus("Selected: " .. model.Name .. " — drag a handle")
    else
        hideHandles()
        setStatus("No block selected")
    end
end

local function getCameraScale(worldPosition)
    camera = workspace.CurrentCamera
    if not camera then
        return 0
    end
    local distance = (camera.CFrame.Position - worldPosition).Magnitude
    return math.max(math.sin(math.rad(camera.FieldOfView)) * distance * 0.035, 0.05)
end

local function updateGizmo()
    camera = workspace.CurrentCamera
    if not selectedModel or not selectedModel.Parent or not camera then
        hideHandles()
        return
    end

    local pivot = selectedModel:GetPivot()
    local size = getModelSize(selectedModel)
    local radius = math.max(size.X, size.Y, size.Z) * 0.7
    local cameraScale = getCameraScale(pivot.Position)
    local ringThickness = math.max(cameraScale * 0.08, 0.015)

    -- CylinderHandleAdornment's cylinder axis is local Y.
    local ringRotations = {
        X = CFrame.Angles(0, 0, math.rad(90)),
        Y = CFrame.new(),
        Z = CFrame.Angles(math.rad(90), 0, 0)
    }

    for _, handle in ipairs(handles) do
        local definition = handle.Definition
        local offset = definition.Direction * (radius + cameraScale * 0.9)
        local worldCFrame = pivot * CFrame.new(offset)
        local screenPoint, onScreen = camera:WorldToViewportPoint(worldCFrame.Position)
        local visible = onScreen and screenPoint.Z > 0

        handle.Visible = visible
        handle.ScreenPosition = Vector2.new(screenPoint.X, screenPoint.Y)

        handle.Sphere.CFrame = worldCFrame
        handle.Sphere.Radius = math.max(cameraScale * 0.55, 0.07)
        handle.Sphere.Visible = visible

        local ring = handle.Ring
        ring.CFrame = pivot * ringRotations[definition.Axis]
        ring.Radius = radius
        ring.InnerRadius = math.max(radius - ringThickness, 0)
        ring.Height = ringThickness
        ring.Visible = true

        local isActiveAxis = dragging and activeHandle
            and handles[activeHandle].Definition.Axis == definition.Axis

        ring.Transparency = isActiveAxis and 0.18 or 0.48
        handle.Sphere.Transparency = isActiveAxis and 0.12 or 0.35
    end
end

--==================================================
-- PICKING + ROTATION
--==================================================

local function raycastBuildModel(viewportPosition)
    camera = workspace.CurrentCamera
    if not camera then
        return nil
    end

    local ray = camera:ViewportPointToRay(viewportPosition.X, viewportPosition.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {BuildModel}
    params.IgnoreWater = true

    local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
    if not result then
        return nil
    end

    local node = result.Instance
    while node and node.Parent ~= BuildModel do
        node = node.Parent
    end

    if node and node.Parent == BuildModel
        and (node:IsA("Model") or node:IsA("BasePart")) then
        return node
    end
    return nil
end

local function findHandleAt(position)
    local nearest
    local nearestDistance = 30

    for index, handle in ipairs(handles) do
        if handle.Visible then
            local distance = (handle.ScreenPosition - position).Magnitude
            if distance <= nearestDistance then
                nearestDistance = distance
                nearest = index
            end
        end
    end
    return nearest
end

local function pointerAngle(position, center)
    local offset = position - center
    return math.atan2(offset.Y, offset.X)
end

local function beginRotation(index, position)
    if not selectedModel or not selectedModel.Parent then
        return false
    end

    camera = workspace.CurrentCamera
    if not camera then
        return false
    end

    local pivot = selectedModel:GetPivot()
    local center, onScreen = camera:WorldToViewportPoint(pivot.Position)
    if not onScreen or center.Z <= 0 then
        setStatus("Selected block is behind the camera")
        return false
    end

    local axisName = handles[index].Definition.Axis
    local axisByName = {
        X = pivot.RightVector,
        Y = pivot.UpVector,
        Z = -pivot.LookVector
    }

    dragStartPivot = pivot
    dragAxis = axisByName[axisName]
    dragCenter = Vector2.new(center.X, center.Y)
    lastAngle = pointerAngle(position, dragCenter)
    totalAngle = 0
    activeHandle = index
    dragging = true

    setStatus("Rotating " .. axisName .. " axis")
    return true
end

local function applyRotation(position)
    if not dragging or not selectedModel or not selectedModel.Parent then
        return
    end

    local angle = pointerAngle(position, dragCenter)
    local delta = angle - lastAngle

    if delta > math.pi then
        delta = delta - math.pi * 2
    elseif delta < -math.pi then
        delta = delta + math.pi * 2
    end

    lastAngle = angle
    totalAngle = totalAngle - delta

    local stepRadians = math.rad(angleStep)
    local snapped = math.round(totalAngle / stepRadians) * stepRadians
    local rotation = CFrame.fromAxisAngle(dragAxis, snapped)
    local pivotPosition = dragStartPivot.Position

    selectedModel:PivotTo(
        CFrame.new(pivotPosition)
        * rotation
        * CFrame.new(-pivotPosition)
        * dragStartPivot
    )
end

local function finishRotation()
    if not dragging then
        return
    end

    dragging = false
    activeHandle = nil
    dragAxis = nil
    dragCenter = nil
    dragStartPivot = nil
    lastAngle = nil
    totalAngle = 0

    local functionsFolder = ReplicatedStorage:FindFirstChild("Functions")
    local commitMove = functionsFolder and functionsFolder:FindFirstChild("CommitMove")

    if selectedModel and selectedModel.Parent and commitMove then
        local ok, err = pcall(function()
            commitMove:InvokeServer(selectedModel, selectedModel:GetPivot())
        end)
        if ok then
            setStatus("Rotation sent to CommitMove")
        else
            setStatus("Rotated locally; CommitMove failed")
            warn("[RotateVisualTest] CommitMove failed:", err)
        end
    elseif selectedModel then
        setStatus("Rotated locally; CommitMove remote not found")
    end
end

local function isPointerOverPanel(position)
    local p = panel.AbsolutePosition
    local s = panel.AbsoluteSize
    return position.X >= p.X and position.X <= p.X + s.X
        and position.Y >= p.Y and position.Y <= p.Y + s.Y
end

local function onPointerBegin(input)
    if cleaned or panelDragging or UserInputService:GetFocusedTextBox() then
        return
    end

    local inputType = input.UserInputType
    if inputType ~= Enum.UserInputType.MouseButton1
        and inputType ~= Enum.UserInputType.Touch then
        return
    end

    local screenPosition = getPointerPosition(input)
    if isPointerOverPanel(screenPosition) then
        return
    end

    local viewportPosition = getViewportPosition(input)
    local handleIndex = selectedModel and findHandleAt(viewportPosition)

    if handleIndex then
        activeInputType = inputType
        touchInput = inputType == Enum.UserInputType.Touch and input or nil
        currentPointer = viewportPosition
        beginRotation(handleIndex, viewportPosition)
        return
    end

    if pickMode then
        local target = raycastBuildModel(viewportPosition)
        if target then
            setSelection(target)
        else
            setSelection(nil)
            setStatus("No BuildModel block under pointer")
        end
    end
end

track(UserInputService.InputBegan:Connect(onPointerBegin))

track(UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end

    if activeInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement then
        currentPointer = getViewportPosition(input)
        applyRotation(currentPointer)
    elseif activeInputType == Enum.UserInputType.Touch
        and touchInput and input == touchInput then
        currentPointer = getViewportPosition(input)
        applyRotation(currentPointer)
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if not dragging then
        return
    end

    if input.UserInputType == activeInputType then
        if activeInputType ~= Enum.UserInputType.Touch or input == touchInput then
            finishRotation()
            activeInputType = nil
            touchInput = nil
            currentPointer = nil
        end
    end
end))

--==================================================
-- UI ACTIONS
--==================================================

track(pickButton.Activated:Connect(function()
    pickMode = not pickMode
    pickButton.Text = pickMode and "PICK: ON" or "PICK: OFF"
    pickButton.BackgroundColor3 = pickMode
        and Color3.fromRGB(55, 105, 180)
        or Color3.fromRGB(65, 68, 78)
    setStatus(pickMode and "Tap a block to select it" or "Pick mode disabled")
end))

track(clearButton.Activated:Connect(function()
    if dragging then
        finishRotation()
    end
    setSelection(nil)
end))

track(stepInput.FocusLost:Connect(function()
    local value = tonumber(stepInput.Text)
    if not value then
        stepInput.Text = tostring(angleStep)
        return
    end

    angleStep = math.clamp(value, 0.1, 10)
    stepInput.Text = tostring(angleStep)
end))

--==================================================
-- CLEANUP
--==================================================

local function cleanup()
    if cleaned then
        return
    end
    cleaned = true

    if dragging then
        finishRotation()
    end

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(connections)

    pcall(function()
        adornmentFolder:Destroy()
    end)
    pcall(function()
        gui:Destroy()
    end)

    selectedModel = nil
    table.clear(handles)
    print("[RotateVisualTest] Cleanup complete")
end

track(closeButton.Activated:Connect(cleanup))

Env.RotateVisualTestCleanup = cleanup
Env.RotateVisualTestSelection = function()
    return selectedModel
end

track(RunService.RenderStepped:Connect(function()
    if not cleaned then
        updateGizmo()
    end
end))

print("========================================")
print("[RotateVisualTest] Standalone test loaded")
print("[RotateVisualTest] Just X Library: NOT REQUIRED")
print("[RotateVisualTest] Toolbar integration: NOT REQUIRED")
print("[RotateVisualTest] Tap a BuildModel block to select")
print("[RotateVisualTest] Drag one of the six sphere handles")
print("[RotateVisualTest] Angle step: 0.1 - 10 degrees")
print("[RotateVisualTest] Cleanup: getgenv().RotateVisualTestCleanup()")
print("========================================")
