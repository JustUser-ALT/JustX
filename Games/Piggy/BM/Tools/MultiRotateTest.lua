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

local ProxyModel = Instance.new("Model")
ProxyModel.Name = "JustXMultiRotateBounds"
local ProxyPart = Instance.new("Part")
ProxyPart.Name = "GroupRotateBounds"
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
ProxyModel.Parent = BuildModel

local Selection = {}
local Outlines = {}
local Connections = {}
local MultiEnabled = false
local Cleaned = false
local CommitBusy = false
local GroupChanged = false
local LastProxyPivot

local function IsRotateMode(mode)
    mode = mode or BuildingMode:Get()
    local name = tostring(mode):match("([^%.]+)$")
    return mode == "Rotate" or name == "Rotate"
        or (type(mode) == "table" and mode.Name == "Rotate")
end

local function IsValidBlock(block)
    return typeof(block) == "Instance"
        and block:IsA("Model")
        and block ~= ProxyModel
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
    LastProxyPivot = ProxyModel:GetPivot()
    GroupChanged = false
    return true
end

local function ResetProxy()
    ProxyPart.Size = Vector3.new(1, 1, 1)
    ProxyModel:PivotTo(CFrame.new(0, -10000, 0))
    LastProxyPivot = nil
end

local function CommitGroup()
    if CommitBusy or not GroupChanged then return end
    CommitBusy = true
    GroupChanged = false
    task.spawn(function()
        for _, block in ipairs(Selection) do
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

local function ApplyProxyDelta()
    if not LastProxyPivot or not IsValidBlock(Selection[#Selection]) then return end
    local current = ProxyModel:GetPivot()
    local delta = current * LastProxyPivot:Inverse()
    if (current.Position - LastProxyPivot.Position).Magnitude > 1e-5
        or current.LookVector:Dot(LastProxyPivot.LookVector) < 0.999999 then
        GroupChanged = true
        for _, block in ipairs(Selection) do
            if IsValidBlock(block) then
                pcall(function()
                    block:PivotTo(delta * block:GetPivot())
                end)
            end
        end
    end
    LastProxyPivot = current
end

local function GetHoveredBlock()
    local ok, result = pcall(function() return Placement:Raycast() end)
    if not ok or not result or not result.Instance then return nil end
    local candidate = result.Instance.Parent
    if IsValidBlock(candidate) then return candidate end
    return nil
end

local function RefreshSelection()
    for index = #Selection, 1, -1 do
        local block = Selection[index]
        if not IsValidBlock(block) then
            table.remove(Selection, index)
            RemoveOutline(block)
        elseif not Outlines[block] then
            CreateOutline(block)
        end
    end
    if #Selection > 0 then
        UpdateProxyBounds()
        ClientState.SelectedBlock = ProxyModel
    else
        ClientState.SelectedBlock = nil
        ResetProxy()
    end
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
    ResetProxy()
    UpdateButton()
end

local function MultiRotatePlaceBlockAction(self, ...)
    if Cleaned or not MultiEnabled or not IsRotateMode() then
        return OriginalPlaceBlockAction(self, ...)
    end

    local block = GetHoveredBlock()
    if block then
        ToggleBlock(block)
    else
        ResetSelection()
    end
    return Enum.ContextActionResult.Sink
end

ClientState.PlaceBlockAction = MultiRotatePlaceBlockAction

-- Feed the proxy model to the original RotateMode. Its rings, handle hit
-- testing, drag math and mobile camera lock remain untouched.
local function WrappedRotateUpdate(self, dt, clientState)
    if Cleaned or not MultiEnabled or not IsRotateMode() or #Selection == 0 then
        return OriginalRotateUpdate(self, dt, clientState)
    end

    RefreshSelection()
    local state = clientState or ClientState
    local previousSelected = state.SelectedBlock
    state.SelectedBlock = ProxyModel

    local results = table.pack(pcall(OriginalRotateUpdate, self, dt, state))
    state.SelectedBlock = previousSelected

    if not results[1] then
        error(results[2], 0)
    end

    ApplyProxyDelta()
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
        ResetProxy()
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
            ApplyProxyDelta()
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
    ClearOutlines()
    table.clear(Selection)
    ClientState.SelectedBlock = nil
    ResetProxy()
    pcall(function() ProxyModel:Destroy() end)
    pcall(function() Gui:Destroy() end)
    if Env.MultiRotateTestCleanup == Cleanup then
        Env.MultiRotateTestCleanup = nil
    end
end

Env.MultiRotateTestCleanup = Cleanup
print("[MultiRotateTest] Loaded. Switch to Rotate, press MULTI, select 2+ blocks, then drag a rotation handle.")
print("[MultiRotateTest] Prototype only. Test rotation, mobile touch, deselection and save before production integration.")
