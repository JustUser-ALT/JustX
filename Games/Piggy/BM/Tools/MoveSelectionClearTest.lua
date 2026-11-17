--==================================================
-- MOVE SELECTION CLEAR TEST
-- Tests whether clearing SelectedBlock removes native Move visuals.
-- No remotes, cloning, placement, resize, or move commit.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Main = Player:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui"):WaitForChild("Main")

local BuildModeFolder = RS:WaitForChild("BuildMode")
local BuildingMode = require(BuildModeFolder:WaitForChild("BuildingMode"))
local Enumeration = require(BuildModeFolder:WaitForChild("Common"):WaitForChild("Enumeration"))

assert(type(getsenv) == "function", "[MoveClear] getsenv is unavailable")

local MainEnv = getsenv(Main)
local ClientState = MainEnv and MainEnv._G and MainEnv._G.BuildModeClient
assert(type(ClientState) == "table", "[MoveClear] Live BuildModeClient not found")

local MoveMode = Enumeration.BuildingMode.Move
assert(MoveMode, "[MoveClear] Native Move enum not found")

local Previous = ClientState.SelectedBlock
if not Previous then
    warn("[MoveClear] SelectedBlock is already nil")
    return
end

print("[MoveClear] Previous selection:", Previous:GetFullName())

ClientState.SelectedBlock = nil
BuildingMode:SetMode(MoveMode)

print("[MoveClear] SelectedBlock after clear:", ClientState.SelectedBlock and ClientState.SelectedBlock:GetFullName() or "nil")
print("[MoveClear] Native Move refresh requested")
