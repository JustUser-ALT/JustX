--==================================================
-- CONCEPTS VISIBLE TOOLBAR SCAN
-- Read-only. Lists visible buttons and their icon data.
-- Output capped at 100 lines.
--==================================================

local Player = game:GetService("Players").LocalPlayer
local roots = {
    Player:WaitForChild("PlayerGui"),
    game:GetService("CoreGui")
}

local MAX_LINES = 100
local lines = {}
local seen = {}

local function add(value)
    if #lines < MAX_LINES then
        lines[#lines + 1] = tostring(value)
    end
end

local function getText(object)
    if object:IsA("TextButton") or object:IsA("TextLabel") or object:IsA("TextBox") then
        return object.Text
    end
    return ""
end

local function isActuallyVisible(object, root)
    local current = object
    while current and current ~= root do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        current = current.Parent
    end
    return true
end

local function pathOf(object)
    local names = {}
    local current = object
    while current and current ~= game do
        table.insert(names, 1, current.Name)
        current = current.Parent
    end
    return table.concat(names, ".")
end

local function imageData(object)
    if object:IsA("ImageButton") or object:IsA("ImageLabel") then
        return "Image=" .. tostring(object.Image)
            .. " | ImageRectOffset=" .. tostring(object.ImageRectOffset)
            .. " | ImageRectSize=" .. tostring(object.ImageRectSize)
    end
    return ""
end

add("=== VISIBLE BUTTON SCAN ===")
add("PlaceId=" .. tostring(game.PlaceId))
add("Only currently visible buttons are included.")
add("")

local count = 0

for _, root in ipairs(roots) do
    local ok, descendants = pcall(function()
        return root:GetDescendants()
    end)

    if ok then
        for _, object in ipairs(descendants) do
            if not seen[object]
                and (object:IsA("TextButton") or object:IsA("ImageButton"))
                and isActuallyVisible(object, root) then

                seen[object] = true
                count += 1

                add("[" .. object.ClassName .. "] " .. pathOf(object))
                add("  Text=" .. string.format("%q", getText(object)))
                add("  Size=" .. tostring(object.Size) .. " | Position=" .. tostring(object.Position))
                add("  " .. imageData(object))

                local parent = object.Parent
                if parent and parent:IsA("GuiObject") then
                    add("  Parent=" .. parent.ClassName .. " " .. parent.Name
                        .. " | Visible=" .. tostring(parent.Visible)
                        .. " | Size=" .. tostring(parent.Size))
                end

                add("")

                if #lines >= MAX_LINES - 4 then
                    break
                end
            end
        end
    end

    if #lines >= MAX_LINES - 4 then
        break
    end
end

add("=== SUMMARY ===")
add("VisibleButtons=" .. tostring(count))
add("OutputLines=" .. tostring(#lines))
if #lines >= MAX_LINES then
    add("TRUNCATED")
end
add("=== END ===")

local report = table.concat(lines, "\n")
if type(setclipboard) == "function" then
    pcall(setclipboard, report)
end

warn(report)
print("[ConceptsToolbarScan] Finished. Read-only scan.")
