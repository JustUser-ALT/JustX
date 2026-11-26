--==================================================
-- ROTATE ICON DISCOVERY
-- Run inside Piggy Build Mode Concepts (the source game).
-- Read-only: prints toolbar Rotate icon image assets.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local lines = {}
local seen = {}

local function Add(value)
    table.insert(lines, tostring(value))
end

local function IsImage(object)
    return object:IsA("ImageLabel") or object:IsA("ImageButton")
end

local function DescribeImage(object)
    local ok, image = pcall(function()
        return object.Image
    end)

    local rectOffset = "?"
    local rectSize = "?"
    pcall(function()
        rectOffset = tostring(object.ImageRectOffset)
        rectSize = tostring(object.ImageRectSize)
    end)

    Add("IMAGE | " .. object:GetFullName())
    Add("  Class=" .. object.ClassName .. " | Name=" .. object.Name)
    Add("  Image=" .. (ok and tostring(image) or "?"))
    Add("  ImageRectOffset=" .. rectOffset .. " | ImageRectSize=" .. rectSize)
    Add("  Visible=" .. tostring(object.Visible) .. " | Size=" .. tostring(object.Size))
end

local function ScanRoot(root, rootLabel, forceAll)
    if not root then
        return
    end

    Add("===== ROOT: " .. rootLabel .. " =====")

    for _, object in ipairs(root:GetDescendants()) do
        if IsImage(object) then
            local path = object:GetFullName()
            local lowerPath = path:lower()

            if forceAll or lowerPath:find("toolbar", 1, true)
                or lowerPath:find("rotate", 1, true) then
                if not seen[object] then
                    seen[object] = true
                    DescribeImage(object)
                end
            end
        elseif object:IsA("TextButton") or object:IsA("TextLabel") then
            local text = tostring(object.Text or "")
            local nameText = (object.Name .. " " .. text):lower()

            if nameText:find("rotate", 1, true) then
                Add("ROTATE CONTROL | " .. object:GetFullName())
                Add("  Class=" .. object.ClassName .. " | Text=" .. string.format("%q", text))
                for _, child in ipairs(object:GetDescendants()) do
                    if IsImage(child) and not seen[child] then
                        seen[child] = true
                        DescribeImage(child)
                    end
                end
            end
        end
    end
end

Add("========== ROTATE ICON DUMP ==========")
Add("PlaceId=" .. tostring(game.PlaceId) .. " | GameId=" .. tostring(game.GameId))

ScanRoot(PlayerGui:FindFirstChild("BuildGui"), "PlayerGui.BuildGui", true)
ScanRoot(PlayerGui:FindFirstChild("BuildModeGui"), "PlayerGui.BuildModeGui", true)

local BuildMode = RS:FindFirstChild("BuildMode")
local Resources = BuildMode and BuildMode:FindFirstChild("Resources")
local Icons = Resources and Resources:FindFirstChild("BuildingModeIcon")
ScanRoot(Icons, "ReplicatedStorage.BuildMode.Resources.BuildingModeIcon", true)

Add("========== END ==========")

local report = table.concat(lines, "\n")
if type(setclipboard) == "function" then
    pcall(setclipboard, report)
end

for line in report:gmatch("[^\n]+") do
    print(line)
end

print("[RotateIconDump] Finished. Read-only; report copied when clipboard is available.")
