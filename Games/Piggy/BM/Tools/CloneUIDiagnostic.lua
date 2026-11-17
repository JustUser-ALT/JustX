-- Clone UI Diagnostic
-- Run in Piggy Build Mode Concepts. Read-only: does not modify the UI.

local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local BuildGui = PlayerGui:WaitForChild("BuildGui")
local Miscellaneous = BuildGui:WaitForChild("Miscellaneous")
local CornerButtons = Miscellaneous:WaitForChild("CornerButtons")
local CloneTool = CornerButtons:WaitForChild("CloneTool")

local function Format(value)
    if typeof(value) == "Color3" then
        return string.format("Color3(%.3f, %.3f, %.3f)", value.R, value.G, value.B)
    elseif typeof(value) == "UDim2" then
        return string.format("UDim2(%s, %s)", tostring(value.X), tostring(value.Y))
    elseif typeof(value) == "UDim" then
        return string.format("UDim(%s, %s)", tostring(value.Scale), tostring(value.Offset))
    elseif typeof(value) == "Vector2" then
        return string.format("Vector2(%.3f, %.3f)", value.X, value.Y)
    elseif typeof(value) == "Rect" then
        return string.format("Rect(%s, %s)", tostring(value.Min), tostring(value.Max))
    elseif typeof(value) == "EnumItem" then
        return tostring(value)
    end
    return tostring(value)
end

local function ReadProperty(object, property)
    local success, value = pcall(function()
        return object[property]
    end)
    if success then
        return Format(value)
    end
    return nil
end

local GuiProperties = {
    "Position", "Size", "AnchorPoint", "Rotation", "Visible",
    "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel",
    "ZIndex", "LayoutOrder", "AutomaticSize", "ClipsDescendants",
    "Image", "ImageColor3", "ImageTransparency", "ScaleType",
    "SliceCenter", "SliceScale", "TileSize",
    "Text", "TextColor3", "TextTransparency", "TextSize",
    "TextScaled", "TextWrapped", "Font", "TextXAlignment",
    "TextYAlignment", "RichText", "LineHeight"
}

local function Dump(object)
    print("\n[CloneUI] " .. object:GetFullName() .. " <" .. object.ClassName .. ">")

    for _, property in ipairs(GuiProperties) do
        local value = ReadProperty(object, property)
        if value ~= nil then
            print("  " .. property .. " = " .. value)
        end
    end

    if object:IsA("UICorner") then
        print("  CornerRadius = " .. Format(object.CornerRadius))
    elseif object:IsA("UIStroke") then
        print("  Color = " .. Format(object.Color))
        print("  Thickness = " .. Format(object.Thickness))
        print("  Transparency = " .. Format(object.Transparency))
        print("  ApplyStrokeMode = " .. Format(object.ApplyStrokeMode))
        print("  LineJoinMode = " .. Format(object.LineJoinMode))
    elseif object:IsA("UIAspectRatioConstraint") then
        print("  AspectRatio = " .. Format(object.AspectRatio))
        print("  DominantAxis = " .. Format(object.DominantAxis))
    elseif object:IsA("UIPadding") then
        print("  PaddingLeft = " .. Format(object.PaddingLeft))
        print("  PaddingRight = " .. Format(object.PaddingRight))
        print("  PaddingTop = " .. Format(object.PaddingTop))
        print("  PaddingBottom = " .. Format(object.PaddingBottom))
    elseif object:IsA("UIScale") then
        print("  Scale = " .. Format(object.Scale))
    end
end

print("========== CLONE UI DIAGNOSTIC ==========")
print("[CloneUI] Target: " .. CloneTool:GetFullName())
print("[CloneUI] Ancestors:")
local ancestor = CloneTool.Parent
while ancestor do
    print("  " .. ancestor:GetFullName() .. " <" .. ancestor.ClassName .. ">")
    ancestor = ancestor.Parent
end

Dump(CloneTool)

for _, descendant in ipairs(CloneTool:GetDescendants()) do
    Dump(descendant)
end

print("\n========== END CLONE UI DIAGNOSTIC ==========")
