--==================================================
-- CLONE TOOL
-- Contextual button integration with native Build Mode Move.
-- Uses the original CloneTool button; does not add a toolbar mode.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")
local Main = BuildModeGui:WaitForChild("Main")
local BuildModel = workspace:WaitForChild("BuildModel")

local BuildModeFolder = RS:WaitForChild("BuildMode")
local BuildingMode = require(BuildModeFolder:WaitForChild("BuildingMode"))
local Enumeration = require(BuildModeFolder:WaitForChild("Common"):WaitForChild("Enumeration"))
local MoveMode = Enumeration.BuildingMode.Move

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
-- ORIGINAL CONTEXTUAL CLONE BUTTON
--==================================================

local BuildGui = PlayerGui:FindFirstChild("BuildGui")
local Miscellaneous = BuildGui and BuildGui:FindFirstChild("Miscellaneous")
local CornerButtons = Miscellaneous and Miscellaneous:FindFirstChild("CornerButtons")
local CloneButton = CornerButtons and CornerButtons:FindFirstChild("CloneTool")

assert(CloneButton and CloneButton:IsA("GuiButton"),
    "[CloneTool] Original BuildGui.Miscellaneous.CornerButtons.CloneTool button not found")

--==================================================
-- TEMPLATE / BLOCK HELPERS
--==================================================

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

    -- Thin Wall is a two-part block. CommitResize needs a part/CFrame/Size
    -- triple for BOTH Base and ColorPart; resizing only ColorPart loses the
    -- wall dimensions when the map is saved and loaded again.
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

local function CloneSelectedBlock()
    if Cleaned then return end
    if BuildingMode:Get() ~= MoveMode then
        warn("[CloneTool] Clone button pressed outside native Move mode")
        return
    end

    local source = ClientState.SelectedBlock
    if not source or not source.Parent then
        warn("[CloneTool] Select a block with Move before cloning")
        return
    end

    local copy = CreateCopy(source)
    if not copy then return end

    PendingClone = copy
    Env.CloneToolPending = copy

    -- Transfer native Move selection to the newly created clone.
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

        -- Refresh native Move after clearing selection; no custom handles.
        BuildingMode:SetMode(MoveMode)
        print("[CloneTool] Move committed; clone selection cleared")
        return result
    end

    return OriginalPlaceBlockAction(self, ...)
end

ClientState.PlaceBlockAction = ClonePlaceBlockAction

table.insert(Connections, CloneButton.Activated:Connect(CloneSelectedBlock))

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
    print("[CloneTool] Cleanup complete")
end

Env.CloneToolCleanup = Cleanup

print("================================")
print("[CloneTool] Loaded")
print("[CloneTool] Original contextual button: CONNECTED")
print("[CloneTool] Native Move selection handoff: READY")
print("[CloneTool] Separate toolbar button / Clone mode: REMOVED")
print("================================")
