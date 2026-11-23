--==================================================
-- PIGGY BUILD MODE CONCEPTS
-- MULTI-SELECT + SNAP UI DIAGNOSTIC
-- Read-only: does not click, modify, or reparent UI.
-- Output: executor console (print), optional clipboard.
--==================================================

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local BuildGui = PlayerGui:WaitForChild("BuildGui")

local MAX_LINES = 420
local Lines = {}

local function Add(value)
    if #Lines < MAX_LINES then
        Lines[#Lines + 1] = tostring(value)
    end
end

local function SafeGet(object, property)
    local ok, value = pcall(function()
        return object[property]
    end)
    if ok then
        return tostring(value)
    end
    return "<unavailable>"
end

local function FullPath(object)
    if not object then
        return "<nil>"
    end

    local parts = {}
    local current = object

    while current and current ~= game do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end

    return table.concat(parts, ".")
end

local function IsA(object, className)
    local ok, result = pcall(function()
        return object:IsA(className)
    end)
    return ok and result
end

local function Describe(object)
    if not object then
        Add("<nil instance>")
        return
    end

    Add("[" .. object.ClassName .. "] " .. FullPath(object))
    Add("  Name=" .. SafeGet(object, "Name"))
    Add("  Parent=" .. (object.Parent and FullPath(object.Parent) or "<nil>"))

    if IsA(object, "GuiObject") then
        Add("  Visible=" .. SafeGet(object, "Visible")
            .. " | Active=" .. SafeGet(object, "Active")
            .. " | Selectable=" .. SafeGet(object, "Selectable")
            .. " | ZIndex=" .. SafeGet(object, "ZIndex"))
        Add("  Size=" .. SafeGet(object, "Size")
            .. " | Position=" .. SafeGet(object, "Position")
            .. " | AnchorPoint=" .. SafeGet(object, "AnchorPoint"))
        Add("  BackgroundColor3=" .. SafeGet(object, "BackgroundColor3")
            .. " | BackgroundTransparency=" .. SafeGet(object, "BackgroundTransparency"))
        Add("  BorderColor3=" .. SafeGet(object, "BorderColor3")
            .. " | BorderSizePixel=" .. SafeGet(object, "BorderSizePixel")
            .. " | AutomaticSize=" .. SafeGet(object, "AutomaticSize"))
        Add("  Rotation=" .. SafeGet(object, "Rotation")
            .. " | ClipsDescendants=" .. SafeGet(object, "ClipsDescendants"))
    end

    if IsA(object, "TextButton") or IsA(object, "TextLabel") or IsA(object, "TextBox") then
        Add("  Text=" .. string.format("%q", SafeGet(object, "Text")))
        Add("  TextColor3=" .. SafeGet(object, "TextColor3")
            .. " | TextTransparency=" .. SafeGet(object, "TextTransparency"))
        Add("  TextSize=" .. SafeGet(object, "TextSize")
            .. " | TextScaled=" .. SafeGet(object, "TextScaled")
            .. " | TextWrapped=" .. SafeGet(object, "TextWrapped"))
        Add("  Font=" .. SafeGet(object, "Font")
            .. " | FontFace=" .. SafeGet(object, "FontFace"))
        Add("  TextXAlignment=" .. SafeGet(object, "TextXAlignment")
            .. " | TextYAlignment=" .. SafeGet(object, "TextYAlignment"))
        Add("  RichText=" .. SafeGet(object, "RichText")
            .. " | LineHeight=" .. SafeGet(object, "LineHeight"))
        Add("  PlaceholderText=" .. SafeGet(object, "PlaceholderText"))
    end

    if IsA(object, "ImageLabel") or IsA(object, "ImageButton") then
        Add("  Image=" .. SafeGet(object, "Image")
            .. " | ImageColor3=" .. SafeGet(object, "ImageColor3"))
        Add("  ImageTransparency=" .. SafeGet(object, "ImageTransparency")
            .. " | ScaleType=" .. SafeGet(object, "ScaleType"))
        Add("  ImageRectOffset=" .. SafeGet(object, "ImageRectOffset")
            .. " | ImageRectSize=" .. SafeGet(object, "ImageRectSize"))
    end

    if IsA(object, "ScrollingFrame") then
        Add("  CanvasSize=" .. SafeGet(object, "CanvasSize")
            .. " | CanvasPosition=" .. SafeGet(object, "CanvasPosition")
            .. " | ScrollBarThickness=" .. SafeGet(object, "ScrollBarThickness"))
    end

    if IsA(object, "UIStroke") then
        Add("  StrokeColor=" .. SafeGet(object, "Color")
            .. " | Thickness=" .. SafeGet(object, "Thickness")
            .. " | Transparency=" .. SafeGet(object, "Transparency")
            .. " | ApplyStrokeMode=" .. SafeGet(object, "ApplyStrokeMode"))
    end

    if IsA(object, "UICorner") then
        Add("  CornerRadius=" .. SafeGet(object, "CornerRadius"))
    end

    if IsA(object, "UIGradient") then
        Add("  Rotation=" .. SafeGet(object, "Rotation")
            .. " | Enabled=" .. SafeGet(object, "Enabled"))
        Add("  Color=" .. SafeGet(object, "Color")
            .. " | Transparency=" .. SafeGet(object, "Transparency"))
    end

    if IsA(object, "UIListLayout") or IsA(object, "UIGridLayout") then
        Add("  FillDirection=" .. SafeGet(object, "FillDirection")
            .. " | HorizontalAlignment=" .. SafeGet(object, "HorizontalAlignment")
            .. " | VerticalAlignment=" .. SafeGet(object, "VerticalAlignment"))
        Add("  Padding=" .. SafeGet(object, "Padding")
            .. " | SortOrder=" .. SafeGet(object, "SortOrder"))
        Add("  CellSize=" .. SafeGet(object, "CellSize")
            .. " | CellPadding=" .. SafeGet(object, "CellPadding"))
    end

    local okAttributes, attributes = pcall(function()
        return object:GetAttributes()
    end)
    if okAttributes and next(attributes) then
        Add("  Attributes:")
        for key, value in pairs(attributes) do
            Add("    " .. tostring(key) .. "=" .. tostring(value))
        end
    end

    local okTags, tags = pcall(function()
        return CollectionService:GetTags(object)
    end)
    if okTags and #tags > 0 then
        Add("  Tags=" .. table.concat(tags, ", "))
    end
end

local function DumpTree(root, maxDepth)
    if not root then
        Add("  TREE: root not found")
        return
    end

    local function walk(node, depth)
        if #Lines >= MAX_LINES - 5 then
            return
        end

        local indent = string.rep("  ", depth)
        Add(indent .. "- " .. node.ClassName .. " " .. node.Name)

        if IsA(node, "TextButton") or IsA(node, "TextLabel") or IsA(node, "TextBox") then
            Add(indent .. "  Text=" .. string.format("%q", SafeGet(node, "Text")))
        elseif IsA(node, "ImageButton") or IsA(node, "ImageLabel") then
            Add(indent .. "  Image=" .. SafeGet(node, "Image"))
        end

        if depth < maxDepth then
            for _, child in ipairs(node:GetChildren()) do
                walk(child, depth + 1)
            end
        end
    end

    walk(root, 0)
end

local function DumpConnections(button, signalName, signal)
    Add("  Signal " .. signalName .. ":")

    if type(getconnections) ~= "function" then
        Add("    getconnections unavailable in this executor")
        return
    end

    local ok, connections = pcall(getconnections, signal)
    if not ok or type(connections) ~= "table" then
        Add("    Could not read connections")
        return
    end

    Add("    Count=" .. tostring(#connections))

    for index, connection in ipairs(connections) do
        local enabled = SafeGet(connection, "Enabled")
        local fn = connection.Function
        local fnInfo = "<no Function field>"

        if type(fn) == "function" then
            fnInfo = tostring(fn)
            if type(debug) == "table" and type(debug.info) == "function" then
                local infoOk, source, line = pcall(debug.info, fn, "sl")
                if infoOk then
                    fnInfo = tostring(source) .. ":" .. tostring(line)
                end
            end
        end

        Add("    #" .. index .. " Enabled=" .. enabled .. " Function=" .. fnInfo)
    end
end

local function FindPath(parent, name)
    if not parent then
        return nil
    end
    return parent:FindFirstChild(name)
end

local Miscellaneous = FindPath(BuildGui, "Miscellaneous")
local CornerButtons = FindPath(Miscellaneous, "CornerButtons")
local MultiSelect = FindPath(CornerButtons, "Multiselect")

local Toolbar = FindPath(BuildGui, "Toolbar")
local Exception = FindPath(Toolbar, "Exception")
local MoveSnap = FindPath(Exception, "MoveSnap")
local RotateSnap = FindPath(Exception, "RotateSnap")

Add("==================================================")
Add("PIGGY BUILD MODE CONCEPTS - UI DIAGNOSTIC")
Add("PlaceId=" .. tostring(game.PlaceId))
Add("Player=" .. LocalPlayer.Name)
Add("Read-only scan; no UI changes or button presses.")
Add("==================================================")

Add("")
Add("========== 1) MULTI-SELECT BUTTON ==========")
if MultiSelect then
    Describe(MultiSelect)
    Add("-- Descendant tree --")
    DumpTree(MultiSelect, 8)

    if IsA(MultiSelect, "GuiButton") then
        Add("-- Event connections --")
        DumpConnections(MultiSelect, "Activated", MultiSelect.Activated)
        DumpConnections(MultiSelect, "MouseButton1Click", MultiSelect.MouseButton1Click)
        DumpConnections(MultiSelect, "MouseButton1Down", MultiSelect.MouseButton1Down)
        DumpConnections(MultiSelect, "MouseButton1Up", MultiSelect.MouseButton1Up)
    end

    Add("-- Parent and sibling objects --")
    if MultiSelect.Parent then
        Describe(MultiSelect.Parent)
        for _, sibling in ipairs(MultiSelect.Parent:GetChildren()) do
            if sibling ~= MultiSelect then
                Describe(sibling)
            end
        end
    end
else
    Add("NOT FOUND: BuildGui.Miscellaneous.CornerButtons.Multiselect")
end

Add("")
Add("========== 2) MOVE SNAP BUTTON ==========")
if MoveSnap then
    Describe(MoveSnap)
    Add("-- Descendant tree --")
    DumpTree(MoveSnap, 8)
    if IsA(MoveSnap, "GuiButton") then
        Add("-- Event connections --")
        DumpConnections(MoveSnap, "Activated", MoveSnap.Activated)
        DumpConnections(MoveSnap, "MouseButton1Click", MoveSnap.MouseButton1Click)
    end
else
    Add("NOT FOUND: BuildGui.Toolbar.Exception.MoveSnap")
end

Add("")
Add("========== 3) ROTATE SNAP BUTTON ==========")
if RotateSnap then
    Describe(RotateSnap)
    Add("-- Descendant tree --")
    DumpTree(RotateSnap, 8)
    if IsA(RotateSnap, "GuiButton") then
        Add("-- Event connections --")
        DumpConnections(RotateSnap, "Activated", RotateSnap.Activated)
        DumpConnections(RotateSnap, "MouseButton1Click", RotateSnap.MouseButton1Click)
    end
else
    Add("NOT FOUND: BuildGui.Toolbar.Exception.RotateSnap")
end

Add("")
Add("========== 4) SNAP INSTANCE COMPARISON ==========")
Add("MoveSnap == RotateSnap: " .. tostring(MoveSnap ~= nil and MoveSnap == RotateSnap))
Add("MoveSnap Parent == RotateSnap Parent: "
    .. tostring(MoveSnap ~= nil and RotateSnap ~= nil and MoveSnap.Parent == RotateSnap.Parent))
Add("MoveSnap Parent: " .. (MoveSnap and FullPath(MoveSnap.Parent) or "<nil>"))
Add("RotateSnap Parent: " .. (RotateSnap and FullPath(RotateSnap.Parent) or "<nil>"))

Add("")
Add("========== 5) EXCEPTION CONTAINER ==========")
if Exception then
    Describe(Exception)
    Add("-- All direct children --")
    for _, child in ipairs(Exception:GetChildren()) do
        Describe(child)
    end
    Add("-- All descendant TextBoxes and buttons --")
    for _, child in ipairs(Exception:GetDescendants()) do
        if IsA(child, "TextBox") or IsA(child, "TextButton") or IsA(child, "ImageButton") then
            Describe(child)
        end
    end
else
    Add("NOT FOUND: BuildGui.Toolbar.Exception")
end

Add("")
Add("========== 6) TOOLBAR TEXTBOXES ==========")
if Toolbar then
    local found = 0
    for _, child in ipairs(Toolbar:GetDescendants()) do
        if IsA(child, "TextBox") then
            found += 1
            Describe(child)
        end
    end
    Add("Toolbar TextBox count=" .. tostring(found))
else
    Add("Toolbar not found")
end

Add("")
Add("========== 7) RELATED UI OBJECTS ==========")
local keywords = {"snap", "grid", "divider", "step", "increment", "multi", "move", "resize", "rotate"}
local foundRelated = 0
for _, object in ipairs(BuildGui:GetDescendants()) do
    local name = string.lower(object.Name)
    local text = ""
    if IsA(object, "TextButton") or IsA(object, "TextLabel") or IsA(object, "TextBox") then
        text = string.lower(SafeGet(object, "Text"))
    end

    for _, keyword in ipairs(keywords) do
        if string.find(name, keyword, 1, true) or string.find(text, keyword, 1, true) then
            foundRelated += 1
            Add(object.ClassName .. " " .. FullPath(object)
                .. " | Text=" .. string.format("%q", SafeGet(object, "Text")))
            break
        end
    end
    if foundRelated >= 55 then
        Add("Related-object listing capped at 55.")
        break
    end
end
Add("Related objects found=" .. tostring(foundRelated))

Add("")
Add("========== END OF REPORT ==========")
Add("Lines emitted=" .. tostring(#Lines) .. " / " .. tostring(MAX_LINES))

local Report = table.concat(Lines, "\n")

print(Report)

if type(setclipboard) == "function" then
    local ok = pcall(setclipboard, Report)
    print("[ConceptsUIDiagnostic] Clipboard copy: " .. (ok and "success" or "failed"))
else
    print("[ConceptsUIDiagnostic] setclipboard unavailable; copy output manually.")
end

print("[ConceptsUIDiagnostic] Finished. Read-only.")
