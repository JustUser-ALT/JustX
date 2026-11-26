--==================================================
-- GRID DIVIDER LAYOUT TEST
-- Isolated position adjustment for MultiMoveTest only.
-- Does not edit or replace MultiMoveTest.lua.
--==================================================

local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local Env = (getgenv and getgenv()) or _G

if type(Env.GridDividerLayoutTestCleanup) == "function" then
    pcall(Env.GridDividerLayoutTestCleanup)
end

local Gui = PlayerGui:WaitForChild("JustXMultiMoveTest", 10)
assert(Gui, "[GridDividerLayoutTest] JustXMultiMoveTest GUI not found. Start MultiMoveTest first.")

local GridDivider = Gui:FindFirstChild("GridDivider", true)
local GridLabel = Gui:FindFirstChild("GridDividerLabel", true)

assert(GridDivider and GridDivider:IsA("TextBox"), "[GridDividerLayoutTest] GridDivider TextBox not found")
assert(GridLabel and GridLabel:IsA("TextLabel"), "[GridDividerLayoutTest] GridDividerLabel not found")

local OriginalInputPosition = GridDivider.Position
local OriginalLabelPosition = GridLabel.Position

-- Initial proposal: 8 px to the right and 6 px upward.
-- Adjust only these offsets while visually testing.
local X_OFFSET = 24
local Y_OFFSET = -14

local function ShiftPosition(position, x, y)
    return UDim2.new(
        position.X.Scale,
        position.X.Offset + x,
        position.Y.Scale,
        position.Y.Offset + y
    )
end

GridDivider.Position = ShiftPosition(OriginalInputPosition, X_OFFSET, Y_OFFSET)
GridLabel.Position = ShiftPosition(OriginalLabelPosition, X_OFFSET, Y_OFFSET)

local Cleaned = false

local function Cleanup()
    if Cleaned then
        return
    end
    Cleaned = true

    if GridDivider and GridDivider.Parent then
        GridDivider.Position = OriginalInputPosition
    end
    if GridLabel and GridLabel.Parent then
        GridLabel.Position = OriginalLabelPosition
    end

    if Env.GridDividerLayoutTestCleanup == Cleanup then
        Env.GridDividerLayoutTestCleanup = nil
    end

    print("[GridDividerLayoutTest] Original positions restored")
end

Env.GridDividerLayoutTestCleanup = Cleanup

print("[GridDividerLayoutTest] Applied: X +" .. X_OFFSET .. " px, Y " .. Y_OFFSET .. " px")
print("[GridDividerLayoutTest] Run getgenv().GridDividerLayoutTestCleanup() to restore")
