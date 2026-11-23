-- Piggy Build Mode Concepts: UI Geometry Diagnostic
-- Read-only. Measures target controls and their ancestor layout chain.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then
    warn("[ConceptsGeometry] LocalPlayer unavailable.")
    return
end

local playerGui = player:FindFirstChildOfClass("PlayerGui")
if not playerGui then
    warn("[ConceptsGeometry] PlayerGui unavailable.")
    return
end

local buildGui = playerGui:FindFirstChild("BuildGui")
if not buildGui then
    warn("[ConceptsGeometry] BuildGui not found.")
    return
end

local lines = {}
local function add(value)
    lines[#lines + 1] = tostring(value)
end

local function safeGet(object, property)
    local ok, value = pcall(function()
        return object[property]
    end)
    if ok then
        return value
    end
    return "<unavailable>"
end

local function fmtVector2(value)
    if typeof(value) == "Vector2" then
        return string.format("(%.2f, %.2f)", value.X, value.Y)
    end
    return tostring(value)
end

local function fmtUDim2(value)
    if typeof(value) == "UDim2" then
        return string.format(
            "Scale(%.5f, %.5f) Offset(%d, %d)",
            value.X.Scale, value.Y.Scale, value.X.Offset, value.Y.Offset
        )
    end
    return tostring(value)
end

local function fullPath(object)
    local ok, result = pcall(function()
        return object:GetFullName()
    end)
    return ok and result or object.Name
end

local function describeGuiObject(object, prefix)
    add(prefix .. "[" .. object.ClassName .. "] " .. fullPath(object))
    add(prefix .. "  Visible=" .. tostring(safeGet(object, "Visible"))
        .. " Active=" .. tostring(safeGet(object, "Active"))
        .. " ZIndex=" .. tostring(safeGet(object, "ZIndex")))
    add(prefix .. "  Position=" .. fmtUDim2(safeGet(object, "Position"))
        .. " Size=" .. fmtUDim2(safeGet(object, "Size")))
    add(prefix .. "  AbsolutePosition=" .. fmtVector2(safeGet(object, "AbsolutePosition"))
        .. " AbsoluteSize=" .. fmtVector2(safeGet(object, "AbsoluteSize")))
    add(prefix .. "  AnchorPoint=" .. tostring(safeGet(object, "AnchorPoint"))
        .. " LayoutOrder=" .. tostring(safeGet(object, "LayoutOrder")))
    add(prefix .. "  AutomaticSize=" .. tostring(safeGet(object, "AutomaticSize"))
        .. " ClipsDescendants=" .. tostring(safeGet(object, "ClipsDescendants")))

    if object:IsA("TextButton") or object:IsA("TextBox") or object:IsA("TextLabel") then
        add(prefix .. "  Text=" .. string.format("%q", safeGet(object, "Text"))
            .. " TextSize=" .. tostring(safeGet(object, "TextSize"))
            .. " TextScaled=" .. tostring(safeGet(object, "TextScaled"))
            .. " Font=" .. tostring(safeGet(object, "Font")))
    end

    if object:IsA("GuiObject") then
        add(prefix .. "  BackgroundColor3=" .. tostring(safeGet(object, "BackgroundColor3"))
            .. " BackgroundTransparency=" .. tostring(safeGet(object, "BackgroundTransparency")))
    end
end

local function describeConstraint(object, prefix)
    local class = object.ClassName
    if class == "UIAspectRatioConstraint" then
        add(prefix .. "UIAspectRatioConstraint AspectRatio=" .. tostring(safeGet(object, "AspectRatio"))
            .. " DominantAxis=" .. tostring(safeGet(object, "DominantAxis")))
    elseif class == "UISizeConstraint" then
        add(prefix .. "UISizeConstraint MinSize=" .. fmtVector2(safeGet(object, "MinSize"))
            .. " MaxSize=" .. fmtVector2(safeGet(object, "MaxSize")))
    elseif class == "UIScale" then
        add(prefix .. "UIScale Scale=" .. tostring(safeGet(object, "Scale")))
    elseif class == "UIGridLayout" then
        add(prefix .. "UIGridLayout CellSize=" .. fmtUDim2(safeGet(object, "CellSize"))
            .. " CellPadding=" .. fmtUDim2(safeGet(object, "CellPadding"))
            .. " FillDirection=" .. tostring(safeGet(object, "FillDirection"))
            .. " HorizontalAlignment=" .. tostring(safeGet(object, "HorizontalAlignment"))
            .. " VerticalAlignment=" .. tostring(safeGet(object, "VerticalAlignment"))
            .. " SortOrder=" .. tostring(safeGet(object, "SortOrder")))
    elseif class == "UIListLayout" then
        add(prefix .. "UIListLayout Padding=" .. tostring(safeGet(object, "Padding"))
            .. " FillDirection=" .. tostring(safeGet(object, "FillDirection"))
            .. " HorizontalAlignment=" .. tostring(safeGet(object, "HorizontalAlignment"))
            .. " VerticalAlignment=" .. tostring(safeGet(object, "VerticalAlignment"))
            .. " SortOrder=" .. tostring(safeGet(object, "SortOrder")))
    elseif class == "UIPadding" then
        add(prefix .. "UIPadding L=" .. tostring(safeGet(object, "PaddingLeft"))
            .. " R=" .. tostring(safeGet(object, "PaddingRight"))
            .. " T=" .. tostring(safeGet(object, "PaddingTop"))
            .. " B=" .. tostring(safeGet(object, "PaddingBottom")))
    end
end

local function describeRelated(parent, prefix)
    if not parent then
        return
    end

    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("UIBase") then
            describeConstraint(child, prefix)
        elseif child:IsA("GuiObject") and (
            child.Name == "TextLabel"
            or child.Name == "Arrow"
            or child.Name == "DropShadow"
            or child.Name == "Frame"
        ) then
            add(prefix .. "Child visual: " .. child.ClassName .. " " .. child.Name
                .. " Visible=" .. tostring(safeGet(child, "Visible"))
                .. " Position=" .. fmtUDim2(safeGet(child, "Position"))
                .. " Size=" .. fmtUDim2(safeGet(child, "Size"))
                .. " AbsolutePosition=" .. fmtVector2(safeGet(child, "AbsolutePosition"))
                .. " AbsoluteSize=" .. fmtVector2(safeGet(child, "AbsoluteSize")))
            if child:IsA("TextLabel") then
                add(prefix .. "  Text=" .. string.format("%q", safeGet(child, "Text"))
                    .. " Font=" .. tostring(safeGet(child, "Font"))
                    .. " TextScaled=" .. tostring(safeGet(child, "TextScaled")))
            elseif child:IsA("ImageLabel") then
                add(prefix .. "  Image=" .. tostring(safeGet(child, "Image")))
            end
        end
    end
end

local camera = Workspace.CurrentCamera
add("==================================================")
add("PIGGY BUILD MODE CONCEPTS - UI GEOMETRY DIAGNOSTIC")
add("PlaceId=" .. tostring(game.PlaceId) .. " | Player=" .. player.Name)
add("Read-only scan. No UI changes, clicks, or input.")
add("==================================================")
if camera then
    add("ViewportSize=" .. fmtVector2(camera.ViewportSize))
end
local insetOk, topLeft, bottomRight = pcall(function()
    return GuiService:GetGuiInset()
end)
if insetOk then
    add("GuiInset TopLeft=" .. fmtVector2(topLeft) .. " BottomRight=" .. fmtVector2(bottomRight))
else
    add("GuiInset=<unavailable>")
end

local screenGui = buildGui:FindFirstAncestorOfClass("ScreenGui")
if screenGui then
    add("ScreenGui=" .. fullPath(screenGui)
        .. " IgnoreGuiInset=" .. tostring(safeGet(screenGui, "IgnoreGuiInset"))
        .. " DisplayOrder=" .. tostring(safeGet(screenGui, "DisplayOrder"))
        .. " ZIndexBehavior=" .. tostring(safeGet(screenGui, "ZIndexBehavior")))
end

local targets = {
    {
        name = "MULTI-SELECT",
        object = buildGui:FindFirstChild("Miscellaneous")
            and buildGui.Miscellaneous:FindFirstChild("CornerButtons")
            and buildGui.Miscellaneous.CornerButtons:FindFirstChild("Multiselect"),
    },
    {
        name = "MOVE SNAP / GRID DIVIDER",
        object = buildGui:FindFirstChild("Toolbar")
            and buildGui.Toolbar:FindFirstChild("Exception")
            and buildGui.Toolbar.Exception:FindFirstChild("MoveSnap"),
    },
    {
        name = "ROTATE SNAP",
        object = buildGui:FindFirstChild("Toolbar")
            and buildGui.Toolbar:FindFirstChild("Exception")
            and buildGui.Toolbar.Exception:FindFirstChild("RotateSnap"),
    },
}

for _, target in ipairs(targets) do
    add("")
    add("========== " .. target.name .. " ==========")
    local object = target.object
    if not object then
        add("NOT FOUND")
    else
        describeGuiObject(object, "")
        describeRelated(object, "  ")

        local ancestor = object.Parent
        local depth = 1
        while ancestor and depth <= 6 do
            add("-- ANCESTOR " .. depth .. " --")
            if ancestor:IsA("GuiObject") then
                describeGuiObject(ancestor, "")
                describeRelated(ancestor, "  ")
            else
                add("[" .. ancestor.ClassName .. "] " .. fullPath(ancestor))
            end
            ancestor = ancestor.Parent
            depth = depth + 1
        end
    end
end

add("")
add("========== SHARED LAYOUT CONTAINERS ==========")
local containers = {
    buildGui:FindFirstChild("Miscellaneous")
        and buildGui.Miscellaneous:FindFirstChild("CornerButtons"),
    buildGui:FindFirstChild("Toolbar"),
    buildGui:FindFirstChild("Toolbar")
        and buildGui.Toolbar:FindFirstChild("Exception"),
}
for _, container in ipairs(containers) do
    if container then
        add("[" .. container.ClassName .. "] " .. fullPath(container))
        if container:IsA("GuiObject") then
            add("  Position=" .. fmtUDim2(container.Position)
                .. " Size=" .. fmtUDim2(container.Size)
                .. " AbsolutePosition=" .. fmtVector2(container.AbsolutePosition)
                .. " AbsoluteSize=" .. fmtVector2(container.AbsoluteSize))
        end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("UIBase") then
                describeConstraint(child, "  ")
            end
        end
    end
end

local report = table.concat(lines, "\n")
print(report)
if setclipboard then
    local ok = pcall(setclipboard, report)
    print("[ConceptsGeometry] Clipboard copy: " .. (ok and "success" or "failed"))
end
print("[ConceptsGeometry] Finished. Read-only scan.")
