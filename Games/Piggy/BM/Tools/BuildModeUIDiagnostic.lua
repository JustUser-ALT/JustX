--==================================================
-- BUILD MODE UI DIAGNOSTIC
-- Prints only the native toolbar, its parent and nearby UI objects.
-- No UI is created or modified.
--==================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")

local ClientState
for attempt = 1, 100 do
    for _, object in ipairs(getgc(true)) do
        if type(object) == "table"
            and rawget(object, "ScreenGui") == BuildModeGui
            and rawget(object, "Toolbar") then
            ClientState = object
            break
        end
    end
    if ClientState then break end
    task.wait(0.1)
end
assert(ClientState, "[BMDIAG] ClientState not found")

local Toolbar = ClientState.Toolbar
local BuildingToolbar = Toolbar and Toolbar.BuildingModeToolbar
local Frame = BuildingToolbar and BuildingToolbar.Instance
assert(Frame and Frame:IsA("GuiObject"), "[BMDIAG] Toolbar frame not found")

local function Describe(object)
    local position = object.AbsolutePosition
    local size = object.AbsoluteSize
    local details = string.format(
        "%s | %s | Visible=%s | AbsPos=(%.1f, %.1f) | AbsSize=(%.1f, %.1f) | Pos=%s | Size=%s",
        object:GetFullName(),
        object.ClassName,
        tostring(object.Visible),
        position.X, position.Y, size.X, size.Y,
        tostring(object.Position),
        tostring(object.Size)
    )

    if object:IsA("TextButton") or object:IsA("TextLabel") then
        details = details .. " | Text=" .. string.sub(object.Text, 1, 50)
    elseif object:IsA("ImageButton") or object:IsA("ImageLabel") then
        details = details .. " | Image=" .. object.Image
    end
    print("[BMDIAG] " .. details)
end

print("[BMDIAG] ===== TOOLBAR =====")
Describe(Frame)

local Parent = Frame.Parent
print("[BMDIAG] ===== TOOLBAR PARENT =====")
Describe(Parent)

print("[BMDIAG] ===== PARENT CHILDREN =====")
for _, child in ipairs(Parent:GetChildren()) do
    if child:IsA("GuiObject") then
        Describe(child)
    end
end

print("[BMDIAG] ===== TOOLBAR DESCENDANTS (GUI OBJECTS ONLY) =====")
local count = 0
for _, child in ipairs(Frame:GetDescendants()) do
    if child:IsA("GuiObject") then
        count += 1
        if count <= 35 then
            Describe(child)
        end
    end
end
print("[BMDIAG] Descendant GUI count: " .. count)
print("[BMDIAG] ===== END =====")
