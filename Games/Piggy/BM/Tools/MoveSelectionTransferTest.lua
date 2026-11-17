--==================================================
-- MOVE SELECTION TRANSFER TEST
-- Transfers the block under the cursor to native Move selection.
-- No cloning, placement, resize, or move commit.
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
local PlacementLogic = require(BuildModeFolder:WaitForChild("PlacementLogic"))

-- Use the live BuildModeClient created by BuildModeGui.Main.
assert(type(getsenv) == "function", "[MoveTransfer] getsenv is unavailable")
local MainEnv = getsenv(Main)
local ClientState = MainEnv and MainEnv._G and MainEnv._G.BuildModeClient
assert(type(ClientState) == "table", "[MoveTransfer] Live BuildModeClient not found")

local MoveMode = Enumeration.BuildingMode.Move
assert(MoveMode, "[MoveTransfer] Native Move enum not found")

-- Resolve the block currently under the cursor using native placement raycasting.
local Placement = PlacementLogic.new()
local ok, result = pcall(function()
    return Placement:Raycast()
end)

if not ok then
    error("[MoveTransfer] Raycast failed: " .. tostring(result))
end

if not result or not result.Instance then
    error("[MoveTransfer] No Build Mode block under cursor")
end

local Target = result.Instance.Parent
if not Target or not Target:IsA("Model") or Target.Parent ~= BuildModel then
    error("[MoveTransfer] Cursor target is not a direct BuildModel block")
end

local Previous = ClientState.SelectedBlock
if Previous == Target then
    warn("[MoveTransfer] Target is already selected by native Move")
    return
end

-- Transfer selection first, then ask the native mode system to refresh Move.
ClientState.SelectedBlock = Target
BuildingMode:SetMode(MoveMode)

print("[MoveTransfer] Previous:", Previous and Previous:GetFullName() or "nil")
print("[MoveTransfer] New selection:", Target:GetFullName())
print("[MoveTransfer] Native Move mode requested")
