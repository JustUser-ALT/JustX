--==================================================
-- CONCEPTS MULTI-SELECT + GRID CONTROL INSPECTOR
-- Read-only. Run in Piggy Build Mode Concepts.
-- Output capped at 110 lines.
--==================================================

local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local BuildGui = PlayerGui:WaitForChild("BuildGui")

local MAX_LINES = 110
local lines = {}
local function add(s)
    if #lines < MAX_LINES then lines[#lines + 1] = tostring(s) end
end

local function pathOf(o)
    local p, node = {}, o
    while node and node ~= game do
        table.insert(p, 1, node.Name)
        node = node.Parent
    end
    return table.concat(p, ".")
end

local function describe(o)
    local s = o.ClassName .. " " .. o.Name
    if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
        s = s .. " | Text=" .. string.format("%q", o.Text)
        s = s .. " | TextColor=" .. tostring(o.TextColor3)
        s = s .. " | TextSize=" .. tostring(o.TextSize)
        s = s .. " | Font=" .. tostring(o.Font)
    end
    if o:IsA("GuiObject") then
        s = s .. " | Visible=" .. tostring(o.Visible)
        s = s .. " | Size=" .. tostring(o.Size)
        s = s .. " | Position=" .. tostring(o.Position)
        s = s .. " | BG=" .. tostring(o.BackgroundColor3)
        s = s .. " | BGTransparency=" .. tostring(o.BackgroundTransparency)
    end
    if o:IsA("ImageLabel") or o:IsA("ImageButton") then
        s = s .. " | Image=" .. tostring(o.Image)
        s = s .. " | ImageColor=" .. tostring(o.ImageColor3)
    end
    if o:IsA("UIStroke") then
        s = s .. " | Color=" .. tostring(o.Color)
        s = s .. " | Thickness=" .. tostring(o.Thickness)
        s = s .. " | Transparency=" .. tostring(o.Transparency)
    end
    if o:IsA("UICorner") then s = s .. " | CornerRadius=" .. tostring(o.CornerRadius) end
    return s
end

local target = BuildGui:FindFirstChild("Miscellaneous")
    and BuildGui.Miscellaneous:FindFirstChild("CornerButtons")
    and BuildGui.Miscellaneous.CornerButtons:FindFirstChild("Multiselect")

add("=== MULTISELECT TARGET ===")
if target then
    add("PATH: " .. pathOf(target))
    add(describe(target))
    add("Attributes:")
    for k, v in pairs(target:GetAttributes()) do add("  " .. k .. "=" .. tostring(v)) end

    add("Children / styling:")
    for _, child in ipairs(target:GetDescendants()) do
        add("  " .. pathOf(child))
        add("    " .. describe(child))
    end

    if target:IsA("GuiButton") and type(getconnections) == "function" then
        local signals = {
            {"Activated", target.Activated},
            {"MouseButton1Click", target.MouseButton1Click}
        }
        for _, item in ipairs(signals) do
            local ok, connections = pcall(getconnections, item[2])
            if ok and type(connections) == "table" then
                add("Connections " .. item[1] .. "=" .. tostring(#connections))
            else
                add("Connections " .. item[1] .. "=unavailable")
            end
        end
    end

    local parent = target.Parent
    if parent then
        add("Parent: " .. describe(parent))
        add("Siblings:")
        for _, sibling in ipairs(parent:GetChildren()) do
            if sibling ~= target then add("  " .. describe(sibling)) end
        end
    end
else
    add("ERROR: Multiselect path not found")
end

add("")
add("=== GRID / STEP TEXTBOXES UNDER BUILDGUI ===")
local textBoxes = {}
for _, o in ipairs(BuildGui:GetDescendants()) do
    if o:IsA("TextBox") then
        table.insert(textBoxes, o)
    end
end
add("TextBox count=" .. tostring(#textBoxes))
for _, o in ipairs(textBoxes) do
    add(pathOf(o))
    add("  " .. describe(o))
    if o.Parent then add("  Parent: " .. describe(o.Parent)) end
end

add("")
add("=== RELEVANT TEXT / NAMES UNDER BUILDGUI ===")
local count = 0
local terms = {"grid", "divider", "step", "snap", "increment", "move", "resize", "rotate"}
for _, o in ipairs(BuildGui:GetDescendants()) do
    local name = o.Name:lower()
    local text = ""
    if o:IsA("TextLabel") or o:IsA("TextButton") then text = o.Text:lower() end
    for _, term in ipairs(terms) do
        if name:find(term, 1, true) or text:find(term, 1, true) then
            add(pathOf(o) .. " | " .. describe(o))
            count += 1
            break
        end
    end
    if count >= 20 then break end
end

add("=== END ===")
local report = table.concat(lines, "\n")
if type(setclipboard) == "function" then pcall(setclipboard, report) end
warn(report)
print("[ConceptsControlInspector] Read-only inspection complete.")
