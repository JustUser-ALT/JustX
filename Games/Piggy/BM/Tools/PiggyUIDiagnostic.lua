--==================================================
-- PIGGY BUILD MODE UI DIAGNOSTIC
-- Read-only inspection for the ORIGINAL Piggy Build Mode.
-- Run in the executor while Build Mode UI is visible.
--==================================================

local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui", 15)

assert(BuildModeGui, "[PiggyUIDiagnostic] BuildModeGui not found")

local function safe(object, property)
    local ok, value = pcall(function()
        return object[property]
    end)
    if ok then return value end
    return nil
end

local function fmt(value)
    if typeof(value) == "UDim2" then
        return string.format(
            "X(%.4f,%d) Y(%.4f,%d)",
            value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset
        )
    elseif typeof(value) == "Vector2" then
        return string.format("(%.2f, %.2f)", value.X, value.Y)
    elseif typeof(value) == "Color3" then
        return string.format(
            "RGB(%d,%d,%d)",
            math.floor(value.R * 255 + 0.5),
            math.floor(value.G * 255 + 0.5),
            math.floor(value.B * 255 + 0.5)
        )
    elseif typeof(value) == "EnumItem" then
        return tostring(value)
    elseif typeof(value) == "Instance" then
        return value:GetFullName()
    end
    return tostring(value)
end

local function isLayoutOrConstraint(object)
    return object:IsA("UIGridLayout")
        or object:IsA("UIListLayout")
        or object:IsA("UIPadding")
        or object:IsA("UISizeConstraint")
        or object:IsA("UIAspectRatioConstraint")
        or object:IsA("UIStroke")
        or object:IsA("UICorner")
end

local function shouldPrint(object)
    if object:IsA("GuiObject") or isLayoutOrConstraint(object) then
        return true
    end
    return false
end

local function printObject(object, index)
    local path = object:GetFullName():gsub("^" .. PlayerGui:GetFullName() .. "%.", "")
    print(string.format("\n[%03d] %s <%s>", index, path, object.ClassName))

    if object:IsA("GuiObject") then
        print("  AbsPos:", fmt(object.AbsolutePosition),
            "AbsSize:", fmt(object.AbsoluteSize))
        print("  Position:", fmt(object.Position),
            "Size:", fmt(object.Size),
            "Anchor:", fmt(object.AnchorPoint))
        print("  Visible:", object.Visible,
            "ZIndex:", object.ZIndex,
            "LayoutOrder:", safe(object, "LayoutOrder"))
    end

    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        print("  Text:", string.format("%q", object.Text),
            "Font:", fmt(object.Font),
            "TextSize:", object.TextSize,
            "TextScaled:", object.TextScaled,
            "TextWrapped:", object.TextWrapped)
        print("  TextColor:", fmt(object.TextColor3),
            "Background:", fmt(object.BackgroundColor3),
            "BackgroundTransparency:", object.BackgroundTransparency)
    elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
        print("  Image:", object.Image,
            "ImageColor:", fmt(object.ImageColor3),
            "ImageTransparency:", object.ImageTransparency,
            "Background:", fmt(object.BackgroundColor3))
    elseif object:IsA("UIGridLayout") then
        print("  CellSize:", fmt(object.CellSize),
            "CellPadding:", fmt(object.CellPadding),
            "FillDirection:", fmt(object.FillDirection),
            "FillOrder:", fmt(object.FillOrder),
            "HorizontalAlignment:", fmt(object.HorizontalAlignment),
            "VerticalAlignment:", fmt(object.VerticalAlignment),
            "SortOrder:", fmt(object.SortOrder))
    elseif object:IsA("UIListLayout") then
        print("  Padding:", fmt(object.Padding),
            "FillDirection:", fmt(object.FillDirection),
            "HorizontalAlignment:", fmt(object.HorizontalAlignment),
            "VerticalAlignment:", fmt(object.VerticalAlignment),
            "SortOrder:", fmt(object.SortOrder))
    elseif object:IsA("UIPadding") then
        print("  Padding L/R/T/B:",
            fmt(object.PaddingLeft), fmt(object.PaddingRight),
            fmt(object.PaddingTop), fmt(object.PaddingBottom))
    elseif object:IsA("UISizeConstraint") then
        print("  MinSize:", fmt(object.MinSize), "MaxSize:", fmt(object.MaxSize))
    elseif object:IsA("UIAspectRatioConstraint") then
        print("  AspectRatio:", object.AspectRatio,
            "DominantAxis:", fmt(object.DominantAxis))
    elseif object:IsA("UIStroke") then
        print("  StrokeColor:", fmt(object.Color),
            "Thickness:", object.Thickness,
            "Transparency:", object.Transparency,
            "ApplyStrokeMode:", fmt(object.ApplyStrokeMode))
    elseif object:IsA("UICorner") then
        print("  CornerRadius:", fmt(object.CornerRadius))
    end
end

print("==================================================")
print("[PiggyUIDiagnostic] ORIGINAL BUILD MODE UI")
print("Viewport:", fmt(workspace.CurrentCamera.ViewportSize))
print("GuiInset:", fmt(game:GetService("GuiService"):GetGuiInset()))
print("Root:", BuildModeGui:GetFullName())
print("==================================================")

local count = 0
local maxObjects = 320

for _, object in ipairs(BuildModeGui:GetDescendants()) do
    if shouldPrint(object) then
        count += 1
        if count <= maxObjects then
            printObject(object, count)
        end
    end
end

print("\n[PiggyUIDiagnostic] Printed:", math.min(count, maxObjects), "of", count, "GUI/layout objects")

-- Explicit ancestor chain for likely toolbar/corner-control containers.
local keywords = {
    "toolbar", "corner", "exception", "move", "rotate",
    "resize", "select", "button", "snap", "build"
}

local printed = {}
local function hasKeyword(name)
    name = string.lower(name)
    for _, keyword in ipairs(keywords) do
        if string.find(name, keyword, 1, true) then
            return true
        end
    end
    return false
end

print("\n================ RELEVANT ANCESTOR CHAINS ================")
for _, object in ipairs(BuildModeGui:GetDescendants()) do
    if object:IsA("GuiObject") and hasKeyword(object.Name) then
        local chain = {}
        local current = object
        while current and current ~= BuildModeGui do
            table.insert(chain, 1, current)
            current = current.Parent
        end

        local key = table.concat((function()
            local names = {}
            for _, item in ipairs(chain) do
                table.insert(names, item.Name)
            end
            return names
        end)(), "/")

        if not printed[key] then
            printed[key] = true
            print("\nCHAIN:", key)
            for depth, item in ipairs(chain) do
                print(string.rep("  ", depth - 1) .. item.Name .. " <" .. item.ClassName .. ">",
                    "Pos:", fmt(safe(item, "Position")),
                    "Size:", fmt(safe(item, "Size")),
                    "AbsPos:", fmt(safe(item, "AbsolutePosition")),
                    "AbsSize:", fmt(safe(item, "AbsoluteSize")))
                for _, child in ipairs(item:GetChildren()) do
                    if isLayoutOrConstraint(child) then
                        print(string.rep("  ", depth) .. "-> " .. child.Name .. " <" .. child.ClassName .. ">")
                    end
                end
            end
        end
    end
end

print("\n[PiggyUIDiagnostic] DONE. No instances or properties were changed.")
