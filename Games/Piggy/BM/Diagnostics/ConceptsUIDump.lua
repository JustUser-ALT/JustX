--==================================================
-- PIGGY BUILD MODE CONCEPTS - UI DISCOVERY
-- Read-only diagnostic. Does not modify game UI or state.
-- Run inside Piggy Build Mode Concepts.
--==================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local function SafeGet(object, property)
    local ok, value = pcall(function()
        return object[property]
    end)
    if ok then
        return tostring(value)
    end
    return "?"
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

local function IsInterestingTextObject(object)
    return object:IsA("TextButton")
        or object:IsA("TextBox")
        or object:IsA("TextLabel")
        or object:IsA("ImageButton")
end

local function Describe(object)
    local details = {
        object.ClassName,
        "Name=" .. object.Name
    }

    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        table.insert(details, "Text=" .. string.format("%q", object.Text))
    end

    if object:IsA("GuiObject") then
        table.insert(details, "Visible=" .. SafeGet(object, "Visible"))
        table.insert(details, "Position=" .. SafeGet(object, "Position"))
        table.insert(details, "Size=" .. SafeGet(object, "Size"))
        table.insert(details, "AnchorPoint=" .. SafeGet(object, "AnchorPoint"))
    end

    if object:IsA("ImageLabel") or object:IsA("ImageButton") then
        table.insert(details, "Image=" .. SafeGet(object, "Image"))
    end

    return table.concat(details, " | ")
end

local roots = {
    {Name = "PlayerGui", Object = PlayerGui},
    {Name = "CoreGui", Object = CoreGui}
}

local output = {}
local totalScreens = 0
local totalControls = 0

table.insert(output, "========== CONCEPTS UI DISCOVERY ==========")
table.insert(output, "PlaceId=" .. tostring(game.PlaceId))
table.insert(output, "GameId=" .. tostring(game.GameId))
table.insert(output, "Player=" .. Player.Name)
table.insert(output, "")

for _, root in ipairs(roots) do
    local ok, descendants = pcall(function()
        return root.Object:GetDescendants()
    end)

    if ok then
        for _, object in ipairs(descendants) do
            if object:IsA("ScreenGui") then
                totalScreens += 1
                table.insert(output, "[" .. root.Name .. "] ScreenGui: " .. GetPath(object))
                table.insert(output, "  Enabled=" .. SafeGet(object, "Enabled")
                    .. " | DisplayOrder=" .. SafeGet(object, "DisplayOrder")
                    .. " | IgnoreGuiInset=" .. SafeGet(object, "IgnoreGuiInset"))

                local guiDescendants = object:GetDescendants()
                local matches = {}

                for _, child in ipairs(guiDescendants) do
                    if IsInterestingTextObject(child) then
                        local description = Describe(child)
                        local searchText = (child.Name .. " " .. description):lower()

                        -- Keep every interactive control and text-bearing object.
                        -- TextLabels are included only when their text/name looks relevant.
                        if child:IsA("TextButton")
                            or child:IsA("TextBox")
                            or child:IsA("ImageButton")
                            or searchText:find("grid")
                            or searchText:find("divider")
                            or searchText:find("multi")
                            or searchText:find("select")
                            or searchText:find("move")
                            or searchText:find("resize")
                            or searchText:find("rotate")
                            or searchText:find("snap")
                            or searchText:find("step") then
                            table.insert(matches, child)
                        end
                    end
                end

                table.insert(output, "  Controls=" .. tostring(#matches))

                for _, child in ipairs(matches) do
                    totalControls += 1
                    table.insert(output, "    " .. GetPath(child))
                    table.insert(output, "      " .. Describe(child))

                    local parent = child.Parent
                    if parent and parent:IsA("GuiObject") then
                        table.insert(output, "      Parent: " .. Describe(parent))
                    end
                end

                table.insert(output, "")
            end
        end
    end
end

table.insert(output, "========== TOTALS ==========")
table.insert(output, "ScreenGuis=" .. tostring(totalScreens))
table.insert(output, "Controls=" .. tostring(totalControls))
table.insert(output, "========== END ==========")

local report = table.concat(output, "\n")

if type(setclipboard) == "function" then
    pcall(setclipboard, report)
    print("[ConceptsUIDump] Report copied to clipboard.")
end

for line in report:gmatch("[^\n]+") do
    print(line)
end

print("[ConceptsUIDump] Finished. Read-only; no UI or game state was changed.")
