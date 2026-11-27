print("[JustXPiggy] Build: 2026-11-27-unload-dialog-fix")

local LibraryUrl = "https://raw.githubusercontent.com/JustUser-ALT/JustXLibrary/a29bba1560fa59cce60e715e6f08588fb44cd126/JustLib.lua"
local LibraryOk, JL = pcall(function()
    return loadstring(game:HttpGet(LibraryUrl))()
end)

if not LibraryOk or type(JL) ~= "table" or type(JL.Window) ~= "function" then
    warn("[JustXPiggy] JustXLibrary failed to load:", JL)
    return
end

local IconPackOk, IconPackResult = pcall(function()
    return JL:LoadIconPack("https://molto.pages.dev/source.lua")
end)
if not IconPackOk or IconPackResult ~= true then
    warn("[JustXPiggy] Lucide icon pack failed to load:", IconPackResult)
end

local Camera = workspace.CurrentCamera
local ViewportWidth = Camera and Camera.ViewportSize.X or 0
local TwoColumns = ViewportWidth >= 436

local Window = JL:Window({
    Title = "JustX Piggy",
    Width = 640,
    Height = 430,
    Columns = TwoColumns and 2 or 1,
    Config = "JustXPiggy",
    SidebarLabels = true
})
if not Window then return end

local PiggyTab = Window:Tab({
    Name = "Piggy",
    Icon = "gamepad-2",
    Type = "Grid"
})
local AdvancedTools = PiggyTab:Section({
    Title = TwoColumns and "Advanced Tools" or "Advanced Tools",
    Column = 1,
    Icon = "wrench"
})
local NewTools = PiggyTab:Section({
    Title = "New Tools",
    Column = TwoColumns and 2 or 1,
    Icon = "sparkles"
})

local Env = (getgenv and getgenv()) or _G
local BaseUrl = "https://raw.githubusercontent.com/JustUser-ALT/JustX/main/Games/Piggy/BM/Tools/"

local ToolConfig = {
    Move = {File = "MoveTool.lua", Cleanup = "MoveToolCleanup"},
    Resize = {File = "ResizeTool.lua", Cleanup = "ResizeToolCleanup"},
    Rotate = {File = "RotateTool.lua", Cleanup = "RotateToolCleanup"},
    Clone = {File = "CloneTool.lua", Cleanup = "CloneToolCleanup"}
}
local ToolToggles = {}

local function stopTool(Name)
    local Config = ToolConfig[Name]
    if not Config then return end
    local Cleanup = Env[Config.Cleanup]
    if type(Cleanup) == "function" then
        local Ok, Error = pcall(Cleanup)
        if not Ok then warn("[JustXPiggy] " .. Name .. " cleanup failed:", Error) end
    end
end

local function startTool(Name)
    local Config = ToolConfig[Name]
    if not Config then return false end
    stopTool(Name)

    local Ok, Error = pcall(function()
        local Source = game:HttpGet(BaseUrl .. Config.File)
        local Chunk, CompileError = loadstring(Source)
        assert(type(Chunk) == "function", CompileError or "loadstring failed")
        Chunk()
    end)

    if not Ok then
        warn("[JustXPiggy] " .. Name .. " failed to start:", Error)
        return false
    end
    print("[JustXPiggy] " .. Name .. " enabled")
    return true
end

local function setTool(Name, Enabled)
    if Enabled then
        if not startTool(Name) then
            local Toggle = ToolToggles[Name]
            if Toggle then Toggle:Set(false) end
        end
    else
        stopTool(Name)
        print("[JustXPiggy] " .. Name .. " disabled")
    end
end

ToolToggles.Move = AdvancedTools:Toggle({
    Name = "Move Tool", Icon = "move", Default = false,
    Flag = "Piggy_BM_Move",
    Callback = function(Value) setTool("Move", Value) end
})
ToolToggles.Resize = AdvancedTools:Toggle({
    Name = "Resize Tool", Icon = "maximize", Default = false,
    Flag = "Piggy_BM_Resize",
    Callback = function(Value) setTool("Resize", Value) end
})
ToolToggles.Rotate = NewTools:Toggle({
    Name = "Rotate Tool", Icon = "rotate-cw", Default = false,
    Flag = "Piggy_BM_Rotate",
    Callback = function(Value) setTool("Rotate", Value) end
})
ToolToggles.Clone = NewTools:Toggle({
    Name = "Clone Tool", Icon = "copy-plus", Default = false,
    Flag = "Piggy_BM_Clone",
    Callback = function(Value) setTool("Clone", Value) end
})

ToolToggles.MultiSelect = NewTools:Toggle({
    Name = "Multi Select Tool", Icon = "layers", Default = false,
    Flag = "Piggy_BM_MultiSelect",
    Callback = function(Value)
        Env.JustXPiggyMultiSelectToolEnabled = Value
        if type(Env.JustXPiggyMultiSelectSetEnabled) == "function" then
            Env.JustXPiggyMultiSelectSetEnabled(Value)
        end
    end
})

JL:OnUnload(function()
    Env.JustXPiggyMultiSelectToolEnabled = false
    if type(Env.JustXPiggyMultiSelectSetEnabled) == "function" then
        pcall(Env.JustXPiggyMultiSelectSetEnabled, false)
    end
    for Name in pairs(ToolConfig) do stopTool(Name) end
end)

print("[JustXPiggy] Loaded")
