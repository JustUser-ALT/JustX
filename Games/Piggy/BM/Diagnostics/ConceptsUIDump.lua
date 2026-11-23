--==================================================
-- PIGGY BUILD MODE CONCEPTS - TARGETED UI DISCOVERY
-- Read-only diagnostic. Output capped at 120 lines.
-- Run inside Piggy Build Mode Concepts.
--==================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local MAX_LINES = 120
local KEYWORDS = {
    "grid", "divider", "multi", "select", "snap",
    "step", "increment", "move", "resize", "rotate",
    "toggle", "spacing"
}

local output = {}
local seen = {}
local candidateCount = 0

local function Add(line)
    if #output < MAX_LINES then
        table.insert(output, tostring(line))
    end
end

local function SafeGet(object, property)
    local ok, value = pcall(function()
        return object[property]
    end)
    return ok and tostring(value) or "?"
end

local function GetPath(object)
    local names = {}
    local current = object
    while current and current ~= game do
        table.insert(names, 1, current.Name)
        current = current.Parent
    end
    return table.concat(names, ".")
end

local function GetText(object)
    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        return object.Text
    end
    return ""
end

local function IsCandidate(object)
    if object:IsA("TextBox") then
        return true, "TEXTBOX"
    end

    if object:IsA("TextButton") or object:IsA("ImageButton") then
        local text = (object.Name .. " " .. GetText(object)):lower()
        for _, keyword in ipairs(KEYWORDS) do
            if text:find(keyword, 1, true) then
                return true, "MATCH:" .. keyword
            end
        end
    end

    if object:IsA("TextLabel") then
        local text = (object.Name .. " " .. GetText(object)):lower()
        for _, keyword in ipairs(KEYWORDS) do
            if text:find(keyword, 1, true) then
                return true, "LABEL:" .. keyword
            end
        end
    end

    return false
end

local function Describe(object)
    local parts = {
        object.ClassName,
        "Name=" .. object.Name
    }

    local text = GetText(object)
    if text ~= "" then
        table.insert(parts, "Text=" .. string.format("%q", text))
    end

    if object:IsA("GuiObject") then
        table.insert(parts, "Visible=" .. SafeGet(object, "Visible"))
        table.insert(parts, "Size=" .. SafeGet(object, "Size"))
        table.insert(parts, "Position=" .. SafeGet(object, "Position"))
    end

    if object:IsA("ImageButton") or object:IsA("ImageLabel") then
        table.insert(parts, "Image=" .. SafeGet(object, "Image"))
    end

    if object:IsA("GuiObject") then
        table.insert(parts, "BG=" .. SafeGet(object, "BackgroundColor3"))
    end

    return table.concat(parts, " | ")
end

local roots = {
    {Name = "PlayerGui", Object = PlayerGui},
    {Name = "CoreGui", Object = CoreGui}
}

Add("========== TARGETED CONCEPTS UI DUMP ==========")
Add("PlaceId=" .. tostring(game.PlaceId) .. " | GameId=" .. tostring(game.GameId))
Add("Only matching controls, TextBoxes and nearby parents are listed.")
Add("Maximum output: " .. MAX_LINES .. " lines.")
Add("")

for _, root in ipairs(roots) do
    local ok, descendants = pcall(function()
        return root.Object:GetDescendants()
    end)

    if ok then
        for _, object in ipairs(descendants) do
            local candidate, reason = IsCandidate(object)
            if candidate and not seen[object] then
                seen[object] = true
                candidateCount += 1

                Add("[" .. root.Name .. "] " .. reason)
                Add(GetPath(object))
                Add("  " .. Describe(object))

                -- Include up to three parent levels to reveal the control's UI container.
                local parent = object.Parent
                for depth = 1, 3 do
                    if not parent or parent == root.Object then break end
                    Add(string.rep("  ", depth) .. "Parent: " .. Describe(parent))
                    parent = parent.Parent
                end
                Add("")
            end
        end
    end
end

Add("========== SUMMARY ==========")
Add("Candidates=" .. tostring(candidateCount))
Add("PrintedLines=" .. tostring(#output))
if #output >= MAX_LINES then
    Add("OUTPUT TRUNCATED: narrow search further if needed.")
end
Add("========== END ==========")

local report = table.concat(output, "\n")

if type(setclipboard) == "function" then
    local ok = pcall(setclipboard, report)
    Add(ok and "[Clipboard] Report copied." or "[Clipboard] Copy failed.")
end

for line in report:gmatch("[^\n]+") do
    print(line)
end

print("[ConceptsUIDump] Finished. Read-only; no game state or UI was changed.")
