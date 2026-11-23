--==================================================
-- MULTI MOVE CENTER HOOK TEST
-- Diagnostic-only hook for the native Move mode.
-- Keeps native Move.Update behavior, but prevents it
-- from replacing the group proxy with SelectedBlock.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")
local BuildModel = workspace:WaitForChild("BuildModel")
local Env = (getgenv and getgenv()) or _G

if type(Env.MultiMoveCenterHookCleanup) == "function" then
    pcall(Env.MultiMoveCenterHookCleanup)
end

local ClientState
assert(type(getgc) == "function", "[MultiMoveCenterHookTest] getgc unavailable")

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

assert(ClientState, "[MultiMoveCenterHookTest] BuildModeClient not found")

local BuildModeFolder = RS:WaitForChild("BuildMode")
local ModesFolder = BuildModeFolder:WaitForChild("Modes")
local MoveMode = require(ModesFolder:WaitForChild("Move"))
local MoveHandles = ClientState.MoveHandles

assert(type(MoveMode) == "table", "[MultiMoveCenterHookTest] Move module unavailable")
assert(type(MoveMode.Update) == "function", "[MultiMoveCenterHookTest] Move.Update unavailable")
assert(type(MoveHandles) == "table", "[MultiMoveCenterHookTest] MoveHandles unavailable")

local ProxyModel = workspace:FindFirstChild("JustXMultiMoveBounds")
assert(ProxyModel and ProxyModel:IsA("Model") and ProxyModel.PrimaryPart,
    "[MultiMoveCenterHookTest] Load MultiMoveTest.lua first; group proxy not found")

local OriginalUpdate = MoveMode.Update
local OriginalRawSetAdornee = rawget(MoveHandles, "SetAdornee")
local RealSetAdornee = MoveHandles.SetAdornee
local Cleaned = false
local SuppressedUpdates = 0
local ProxyAssignments = 0

local function IsGroupArmed(state)
    local selected = state.SelectedBlock
    return typeof(selected) == "Instance"
        and selected:IsA("Model")
        and selected.Parent == BuildModel
        and ProxyModel.Parent == workspace
end

local function WrappedUpdate(self, ...)
    if Cleaned or not IsGroupArmed(ClientState) then
        return OriginalUpdate(self, ...)
    end

    -- Suppress only Move.Update's SetAdornee(driver) call.
    -- The hover/box adornment and all other native Update logic remain intact.
    rawset(MoveHandles, "SetAdornee", function()
        SuppressedUpdates += 1
    end)

    local results = table.pack(pcall(OriginalUpdate, self, ...))

    if OriginalRawSetAdornee ~= nil then
        rawset(MoveHandles, "SetAdornee", OriginalRawSetAdornee)
    else
        rawset(MoveHandles, "SetAdornee", nil)
    end

    if not results[1] then
        warn("[MultiMoveCenterHookTest] Native Move.Update failed:", results[2])
        error(results[2], 0)
    end

    if IsGroupArmed(ClientState) then
        local ok, err = pcall(RealSetAdornee, MoveHandles, ProxyModel)
        if ok then
            ProxyAssignments += 1
        else
            warn("[MultiMoveCenterHookTest] Proxy assignment failed:", err)
        end
    end

    return table.unpack(results, 2, results.n)
end

MoveMode.Update = WrappedUpdate

local function Cleanup()
    if Cleaned then return end
    Cleaned = true

    if MoveMode.Update == WrappedUpdate then
        MoveMode.Update = OriginalUpdate
    end

    if OriginalRawSetAdornee ~= nil then
        rawset(MoveHandles, "SetAdornee", OriginalRawSetAdornee)
    else
        rawset(MoveHandles, "SetAdornee", nil)
    end

    if Env.MultiMoveCenterHookCleanup == Cleanup then
        Env.MultiMoveCenterHookCleanup = nil
    end

    print("[MultiMoveCenterHookTest] Cleanup complete")
end

Env.MultiMoveCenterHookCleanup = Cleanup

print("================================")
print("[MultiMoveCenterHookTest] Installed")
print("[MultiMoveCenterHookTest] Keep MultiMoveTest.lua loaded")
print("[MultiMoveCenterHookTest] Enable Multi Select, select 2+ blocks, then arm Group Move")
print("[MultiMoveCenterHookTest] Check whether arrows move to the group center")
print("[MultiMoveCenterHookTest] Cleanup: MultiMoveCenterHookCleanup()")
print("================================")

task.spawn(function()
    while not Cleaned do
        task.wait(5)
        if Cleaned then break end
        print(string.format(
            "[MultiMoveCenterHookTest] suppressed updates=%d | proxy assignments=%d | armed=%s",
            SuppressedUpdates,
            ProxyAssignments,
            tostring(IsGroupArmed(ClientState))
        ))
    end
end)
