--==================================================
-- MULTI MOVE TEST
-- Isolated Multi Select + group Move prototype.
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
local ChangedEvent = BuildModeFolder:WaitForChild("Events"):WaitForChild("BuildingModeChanged")
local PlacementLogic = require(BuildModeFolder:WaitForChild("PlacementLogic"))
local BoxSelectionAdornment = require(
    RS:WaitForChild("Packages")
        :WaitForChild("CustomAdornments")
        :WaitForChild("BoxSelectionAdornment")
)

local Env = (getgenv and getgenv()) or _G

if type(Env.MultiMoveTestCleanup) == "function" then
    pcall(Env.MultiMoveTestCleanup)
end
if type(Env.MultiSelectTestCleanup) == "function" then
    pcall(Env.MultiSelectTestCleanup)
end

local ClientState
assert(type(getgc) == "function", "[MultiMoveTest] getgc unavailable")

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

assert(ClientState, "[MultiMoveTest] BuildModeClient not found")
assert(type(ClientState.PlaceBlockAction) == "function", "[MultiMoveTest] PlaceBlockAction unavailable")
assert(ClientState.MoveHandles, "[MultiMoveTest] MoveHandles unavailable")

local OriginalPlaceBlockAction = ClientState.PlaceBlockAction
local MoveHandles = ClientState.MoveHandles
local Placement = PlacementLogic.new()
local AdornmentParent = BuildModeGui:WaitForChild("Frame"):WaitForChild("Adornment")

local oldGui = PlayerGui:FindFirstChild("JustXMultiMoveTest")
if oldGui then oldGui:Destroy() end

local Gui = Instance.new("ScreenGui")
Gui.Name = "JustXMultiMoveTest"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 10002
Gui.Enabled = false
Gui.Parent = PlayerGui

local Toggle = Instance.new("TextButton")
Toggle.Name = "MultiMoveToggle"
Toggle.Size = UDim2.fromOffset(112, 42)
Toggle.Position = UDim2.new(1, -124, 0.56, 0)
Toggle.BackgroundColor3 = Color3.fromRGB(42, 46, 55)
Toggle.BorderSizePixel = 0
Toggle.Text = "GROUP MOVE OFF"
Toggle.TextColor3 = Color3.fromRGB(235, 238, 245)
Toggle.TextSize = 11
Toggle.Font = Enum.Font.GothamBold
Toggle.Visible = false
Toggle.Parent = Gui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 9)
ToggleCorner.Parent = Toggle

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(0, 0, 255)
ToggleStroke.Thickness = 1
ToggleStroke.Transparency = 0.15
ToggleStroke.Parent = Toggle

local Status = Instance.new("TextLabel")
Status.Name = "SelectionStatus"
Status.Size = UDim2.fromOffset(112, 20)
Status.Position = UDim2.new(1, -124, 0.56, 44)
Status.BackgroundTransparency = 1
Status.Text = "0 selected"
Status.TextColor3 = Color3.fromRGB(220, 225, 235)
Status.TextSize = 11
Status.Font = Enum.Font.Gotham
Status.Visible = false
Status.Parent = Gui

local Selection = {}
local Outlines = {}
local Connections = {}
local MultiEnabled = false
local Cleaned = false
local DragSession = nil
local CommitBusy = false

local function ModeName()
    local mode = BuildingMode:Get()
    if mode == nil then return "" end
    local ok, name = pcall(function() return mode.Name end)
    if ok and type(name) == "string" then return name end
    return tostring(mode):match("([^%.]+)$") or tostring(mode)
end

local function IsMoveMode()
    return ModeName() == "Move"
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

local function UpdateStatus()
    Status.Text = tostring(#Selection) .. " selected"
    Toggle.Text = MultiEnabled and "GROUP MOVE ON" or "GROUP MOVE OFF"
    Toggle.BackgroundColor3 = MultiEnabled
        and Color3.fromRGB(55, 105, 78)
        or Color3.fromRGB(42, 46, 55)
end

local function CreateOutline(block)
    local outline = BoxSelectionAdornment.new()
    outline:SetParent(AdornmentParent)
    outline:SetColor(Color3.fromRGB(0, 0, 255))
    outline:SetThickness(0.1)
    outline:SetAdornee(block)
    Outlines[block] = outline
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
    local driver = Selection[#Selection]
    if IsValidBlock(driver) then
        ClientState.SelectedBlock = driver
    end
end

local function ClearSelection()
    for block in pairs(Outlines) do
        RemoveOutline(block)
    end
    table.clear(Selection)
    UpdateStatus()
end

local function ToggleBlock(block)
    if not IsValidBlock(block) then return end

    local index = FindIndex(block)
    if index then
        table.remove(Selection, index)
        RemoveOutline(block)
        print("[MultiMoveTest] Removed:", block:GetFullName())
    else
        table.insert(Selection, block)
        CreateOutline(block)
        print("[MultiMoveTest] Added:", block:GetFullName())
    end

    SetDriver()
    UpdateStatus()
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

    local block = GetHoveredBlock()
    if block then
        ToggleBlock(block)
    else
        print("[MultiMoveTest] Click ignored: no BuildModel block under pointer")
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
end

local function FindCommitMove()
    local candidates = {
        ClientState.Functions,
        rawget(ClientState, "Functions"),
        BuildModeFolder:FindFirstChild("Functions")
    }

    for _, container in ipairs(candidates) do
        if typeof(container) == "Instance" then
            local remote = container:FindFirstChild("CommitMove")
            if remote and remote:IsA("RemoteFunction") then return remote end
        elseif type(container) == "table" then
            local remote = rawget(container, "CommitMove")
            if typeof(remote) == "Instance" and remote:IsA("RemoteFunction") then
                return remote
            end
        end
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
        warn("[MultiMoveTest] CommitMove RemoteFunction not found; other blocks were moved locally only")
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
                    warn("[MultiMoveTest] CommitMove failed for", block:GetFullName(), err)
                end
            end
        end
        CommitBusy = false
        print("[MultiMoveTest] Group commit pass finished")
    end)
end

local function BeginGroupDrag()
    if not MultiEnabled or not IsMoveMode() or #Selection < 2 then
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
    print("[MultiMoveTest] Group drag started; driver:", driver:GetFullName())
end

local function UpdateVisibility()
    local visible = IsMoveMode()
    Gui.Enabled = visible
    Toggle.Visible = visible
    Status.Visible = visible
end

table.insert(Connections, Toggle.Activated:Connect(function()
    if not IsMoveMode() then return end
    MultiEnabled = not MultiEnabled
    if not MultiEnabled then
        DragSession = nil
        ClearSelection()
    end
    UpdateStatus()
    print("[MultiMoveTest] Group Move:", MultiEnabled and "ON" or "OFF")
end))

table.insert(Connections, ChangedEvent.Event:Connect(function()
    task.defer(UpdateVisibility)
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
    end)
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if Cleaned then return end

    for index = #Selection, 1, -1 do
        local block = Selection[index]
        if not IsValidBlock(block) then
            table.remove(Selection, index)
            RemoveOutline(block)
        end
    end

    if MultiEnabled and IsMoveMode() then
        if DragSession then
            ApplyGroupDelta()
        end
        SetDriver()
    end
    UpdateStatus()
end))

ClientState.PlaceBlockAction = MultiMovePlaceBlockAction
UpdateVisibility()
UpdateStatus()

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

    ClearSelection()
    pcall(function() Gui:Destroy() end)

    if Env.MultiMoveTestCleanup == Cleanup then
        Env.MultiMoveTestCleanup = nil
    end
    print("[MultiMoveTest] Cleanup complete")
end

Env.MultiMoveTestCleanup = Cleanup

print("================================")
print("[MultiMoveTest] Loaded")
print("[MultiMoveTest] Select Move mode, enable GROUP MOVE, then select 2+ blocks")
print("[MultiMoveTest] Drag the native Move arrows to move the group")
print("[MultiMoveTest] Other blocks are committed individually on release")
print("[MultiMoveTest] Use MultiMoveTestCleanup() to unload")
print("================================")
