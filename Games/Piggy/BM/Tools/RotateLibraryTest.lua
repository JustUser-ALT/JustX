--==================================================
-- JUST X LIBRARY · PIGGY ROTATE TEST
-- Loads the existing RotateTool.lua implementation.
-- No duplicate gizmo, toolbar, or selection implementation here.
--==================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("[RotateLibraryTest] LocalPlayer unavailable")
    return
end

local Env = (getgenv and getgenv()) or _G
local LibraryUrl = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/main/JustLib.lua"
local ToolUrl = "https://raw.githubusercontent.com/JustUser-ALT/JustX/main/Games/Piggy/BM/Tools/RotateTool.lua"

-- Clean up a previous copy of this test loader.
if type(Env.RotateLibraryTestCleanup) == "function" then
    pcall(Env.RotateLibraryTestCleanup)
end

local LibraryOk, JL = pcall(function()
    return loadstring(game:HttpGet(LibraryUrl))()
end)

if not LibraryOk or type(JL) ~= "table" or type(JL.Window) ~= "function" then
    warn("[RotateLibraryTest] JustXLibrary failed to load:", JL)
    return
end

local Window = JL:Window({
    Title = "Piggy · Rotate Test",
    Width = 420,
    Height = 300,
    Columns = 1,
    Config = "JustXPiggy_RotateTest",
    SidebarLabels = true
})

if not Window then
    warn("[RotateLibraryTest] Window creation failed")
    return
end

local Tab = Window:Tab({
    Name = "Rotate",
    Icon = "rotate-3d",
    Type = "Grid"
})

local Section = Tab:Section({
    Title = "Build Mode",
    Column = 1,
    Icon = "wrench"
})

local Enabled = false
local Destroyed = false

local function stopRotate()
    local cleanup = Env.RotateTestCleanup
    if type(cleanup) == "function" then
        local ok, err = pcall(cleanup)
        if not ok then
            warn("[RotateLibraryTest] Rotate cleanup failed:", err)
        end
    end
    Enabled = false
end

local function startRotate()
    stopRotate()

    local ok, err = pcall(function()
        local source = game:HttpGet(ToolUrl)
        assert(type(source) == "string" and #source > 0, "RotateTool source is empty")

        local chunk, compileError = loadstring(source)
        assert(type(chunk) == "function", compileError or "RotateTool compile failed")

        chunk()
        assert(type(Env.RotateTestCleanup) == "function", "RotateTool did not register RotateTestCleanup")
    end)

    if not ok then
        stopRotate()
        warn("[RotateLibraryTest] Rotate failed to start:", err)
        return false
    end

    Enabled = true
    print("[RotateLibraryTest] RotateTool enabled")
    return true
end

local Toggle
Toggle = Section:Toggle({
    Name = "Rotate Tool",
    Icon = "rotate-cw",
    Default = false,
    Flag = "Piggy_RotateLibraryTest",
    Callback = function(value)
        if Destroyed then return end

        if value then
            if not startRotate() and Toggle then
                Toggle:Set(false)
            end
        else
            stopRotate()
        end
    end
})

Section:Text({
    Text = "Используется существующий RotateTool.lua. Вращательные кольца и логика не дублируются в этом загрузчике."
})

Section:Button({
    Name = "Unload Rotate Test",
    Callback = function()
        if Toggle then
            Toggle:Set(false)
        end
        stopRotate()
    end
})

local function Cleanup()
    if Destroyed then return end
    Destroyed = true
    stopRotate()
    if Window and type(Window.Destroy) == "function" then
        pcall(function() Window:Destroy() end)
    end
    if Env.RotateLibraryTestCleanup == Cleanup then
        Env.RotateLibraryTestCleanup = nil
    end
    print("[RotateLibraryTest] Unloaded")
end

Env.RotateLibraryTestCleanup = Cleanup
JL:OnUnload(Cleanup)

print("[RotateLibraryTest] Loaded · enable Rotate Tool to start")
