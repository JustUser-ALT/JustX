--==================================================
-- JUSTX PIGGY LOCAL MORPH
-- Local-only visual replacement based on the tested Ombra rig.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

local CLONE_NAME = "Ombra_LocalReplacement"
local OFFSET = CFrame.new(0, 1.04, 0)

local ANIMATIONS = {
    Idle = "9700953169",
    Walk = "9700959017",
    Run = "9700967732",
    Jump = "9700976238",
    Fall = "9700980383"
}

if _G.StopOmbraReplacement then
    _G.StopOmbraReplacement()
end

local Previous = workspace:FindFirstChild(CLONE_NAME)
if Previous then Previous:Destroy() end

local Character = Player.Character or Player.CharacterAdded:Wait()
local PlayerHumanoid = Character:WaitForChild("Humanoid")
local PlayerRoot = Character:WaitForChild("HumanoidRootPart")

local Original = workspace
    :WaitForChild("GameFolder")
    :WaitForChild("PiggyNPC")
    :WaitForChild("Ombra")

local Clone = Original:Clone()
Clone.Name = CLONE_NAME

for _, Object in ipairs(Clone:GetDescendants()) do
    if Object:IsA("Script") or Object:IsA("LocalScript") then
        Object.Disabled = true
    end
end

local Root = Clone:FindFirstChild("HumanoidRootPart", true)
local Humanoid = Clone:FindFirstChildOfClass("Humanoid")

if not Root or not Humanoid then
    warn("[Ombra] Root or Humanoid not found")
    Clone:Destroy()
    return
end

Clone.PrimaryPart = Root

for _, Object in ipairs(Clone:GetDescendants()) do
    if Object:IsA("BasePart") then
        Object.CollisionGroup = "Players"
        Object.CanCollide = false
        Object.CanTouch = false
        Object.CanQuery = false
        Object.Massless = true
        Object.Anchored = false
    end
end

Root.Anchored = true
Humanoid.AutoRotate = false

Clone.Parent = workspace
Clone:PivotTo(PlayerRoot.CFrame * OFFSET)

local Animator = Humanoid:FindFirstChildOfClass("Animator")
if not Animator then
    Animator = Instance.new("Animator")
    Animator.Parent = Humanoid
end

local Tracks = {}

local function LoadAnimation(Name, ID, Looped, Priority)
    local Animation = Instance.new("Animation")
    Animation.AnimationId = "rbxassetid://" .. ID

    local Track = Animator:LoadAnimation(Animation)
    Track.Looped = Looped
    Track.Priority = Priority
    Tracks[Name] = Track

    Animation:Destroy()
end

LoadAnimation("Idle", ANIMATIONS.Idle, true, Enum.AnimationPriority.Movement)
LoadAnimation("Walk", ANIMATIONS.Walk, true, Enum.AnimationPriority.Movement)
LoadAnimation("Run", ANIMATIONS.Run, true, Enum.AnimationPriority.Movement)
LoadAnimation("Jump", ANIMATIONS.Jump, false, Enum.AnimationPriority.Action)
LoadAnimation("Fall", ANIMATIONS.Fall, true, Enum.AnimationPriority.Movement)

local CurrentAnimation

local function PlayAnimation(Name)
    local NewTrack = Tracks[Name]
    if not NewTrack then return end

    if CurrentAnimation == Name and NewTrack.IsPlaying then return end

    if CurrentAnimation then
        local OldTrack = Tracks[CurrentAnimation]
        if OldTrack and OldTrack.IsPlaying then
            OldTrack:Stop(0.15)
        end
    end

    CurrentAnimation = Name
    NewTrack:Play(0.15)
end

local SavedParts = {}
local SavedTextures = {}

for _, Object in ipairs(Character:GetDescendants()) do
    if Object:IsA("BasePart") then
        SavedParts[Object] = Object.LocalTransparencyModifier
        Object.LocalTransparencyModifier = 1
    elseif Object:IsA("Decal") or Object:IsA("Texture") then
        SavedTextures[Object] = Object.Transparency
        Object.Transparency = 1
    end
end

local OldDisplayDistanceType = PlayerHumanoid.DisplayDistanceType
PlayerHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

local Stopped = false
local RenderConnection
local DiedConnection
local RemovingConnection

local function Stop()
    if Stopped then return end
    Stopped = true

    if RenderConnection then RenderConnection:Disconnect() end
    if DiedConnection then DiedConnection:Disconnect() end
    if RemovingConnection then RemovingConnection:Disconnect() end

    for _, Track in pairs(Tracks) do
        pcall(function()
            Track:Stop(0)
            Track:Destroy()
        end)
    end

    if Clone and Clone.Parent then Clone:Destroy() end

    for Part, Transparency in pairs(SavedParts) do
        if Part and Part.Parent then
            Part.LocalTransparencyModifier = Transparency
        end
    end

    for Object, Transparency in pairs(SavedTextures) do
        if Object and Object.Parent then
            Object.Transparency = Transparency
        end
    end

    if PlayerHumanoid and PlayerHumanoid.Parent then
        PlayerHumanoid.DisplayDistanceType = OldDisplayDistanceType
    end

    if _G.StopOmbraReplacement == Stop then
        _G.StopOmbraReplacement = nil
    end

    print("[Ombra] Replacement stopped")
end

_G.StopOmbraReplacement = Stop

local function UpdateAnimation()
    local State = PlayerHumanoid:GetState()

    if State == Enum.HumanoidStateType.Jumping then
        PlayAnimation("Jump")
        return
    end

    if State == Enum.HumanoidStateType.Freefall then
        PlayAnimation("Fall")
        return
    end

    local Velocity = PlayerRoot.AssemblyLinearVelocity
    local HorizontalSpeed = Vector3.new(Velocity.X, 0, Velocity.Z).Magnitude
    local Moving = PlayerHumanoid.MoveDirection.Magnitude > 0.05 or HorizontalSpeed > 0.8

    if Moving then
        local IsRunning =
            PlayerHumanoid.WalkSpeed > 18
            or HorizontalSpeed > math.max(18, PlayerHumanoid.WalkSpeed * 1.15)

        PlayAnimation(IsRunning and "Run" or "Walk")
    else
        PlayAnimation("Idle")
    end
end

PlayAnimation("Idle")

RenderConnection = RunService.RenderStepped:Connect(function()
    if Stopped then return end

    if not Character.Parent or not PlayerRoot.Parent or not Clone.Parent
        or PlayerHumanoid.Health <= 0 then
        Stop()
        return
    end

    Clone:PivotTo(PlayerRoot.CFrame * OFFSET)
    UpdateAnimation()
end)

DiedConnection = PlayerHumanoid.Died:Connect(Stop)

RemovingConnection = Player.CharacterRemoving:Connect(function(RemovingCharacter)
    if RemovingCharacter == Character then Stop() end
end)

print("[Ombra] Local Skin Changer loaded")
print("[Ombra] CollisionGroup: Players")
print("[Ombra] Animations: 5")
print("[Ombra] Replacement active")
print("Stop: _G.StopOmbraReplacement()")
