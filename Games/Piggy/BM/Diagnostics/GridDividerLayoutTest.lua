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
local OriginalInputSize = GridDivider.Size

local Corner = GridDivider:FindFirstChildOfClass("UICorner")
local CreatedCorner = false
local OriginalCornerRadius

if not Corner then
    Corner = Instance.new("UICorner")
    Corner.Name = "GridDividerTestCorner"
    Corner.Parent = GridDivider
    CreatedCorner = true
else
    OriginalCornerRadius = Corner.CornerRadius
end

-- Layout test: move the control farther right and slightly enlarge it.
local X_OFFSET = 40
local Y_OFFSET = -14
local INPUT_WIDTH = 64
local INPUT_HEIGHT = 30
local CORNER_RADIUS = 7

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
GridDivider.Size = UDim2.fromOffset(INPUT_WIDTH, INPUT_HEIGHT)
Corner.CornerRadius = UDim.new(0, CORNER_RADIUS)

local Cleaned = false

local function Cleanup()
    if Cleaned then
        return
    end
    Cleaned = true

    if GridDivider and GridDivider.Parent then
        GridDivider.Position = OriginalInputPosition
        GridDivider.Size = OriginalInputSize
    end
    if GridLabel and GridLabel.Parent then
        GridLabel.Position = OriginalLabelPosition
    end
    if Corner and Corner.Parent then
        if CreatedCorner then
            Corner:Destroy()
        elseif OriginalCornerRadius then
            Corner.CornerRadius = OriginalCornerRadius
        end
    end

    if Env.GridDividerLayoutTestCleanup == Cleanup then
        Env.GridDividerLayoutTestCleanup = nil
    end

    print("[GridDividerLayoutTest] Original positions restored")
end

Env.GridDividerLayoutTestCleanup = Cleanup

print("[GridDividerLayoutTest] Applied: X +" .. X_OFFSET .. " px, Y " .. Y_OFFSET .. " px, size " .. INPUT_WIDTH .. "x" .. INPUT_HEIGHT .. ", rounded corners")
print("[GridDividerLayoutTest] Run getgenv().GridDividerLayoutTestCleanup() to restore")
