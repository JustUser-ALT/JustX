--==================================================
-- MOVE HANDLES ADORNEE TRACE
-- Rate-limited monitor for MultiMoveTest.
-- Counts frequent SetAdornee calls without flooding the console.
-- Does not move blocks or alter BuildMode selection.
--==================================================

local Players = game:GetService("Players")
local Env = (getgenv and getgenv()) or _G
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local BuildModeGui = PlayerGui:WaitForChild("BuildModeGui")

if type(Env.MoveHandlesAdorneeTraceCleanup) == "function" then
    pcall(Env.MoveHandlesAdorneeTraceCleanup)
end

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

assert(ClientState, "[MoveHandlesAdorneeTrace] BuildModeClient state not found")

local MoveHandles = rawget(ClientState, "MoveHandles")
assert(type(MoveHandles) == "table", "[MoveHandlesAdorneeTrace] MoveHandles not found")

local OriginalRawSetAdornee = rawget(MoveHandles, "SetAdornee")
local OriginalSetAdornee = MoveHandles.SetAdornee
assert(type(OriginalSetAdornee) == "function", "[MoveHandlesAdorneeTrace] SetAdornee method not found")

local Active = true
local HookInstalled = false
local SetCallCount = 0
local SetTargetChangeCount = 0
local LastReportAt = os.clock()
local LastTraceAt = 0
local LastAdornee = rawget(MoveHandles, "_Adornee")
local LastSelected = rawget(ClientState, "SelectedBlock")
local LastHookTarget = LastAdornee
local LastHookTargetDescription = nil

local function Describe(value)
    if typeof(value) == "Instance" then
        local name = value.Name
        local ok, fullName = pcall(function()
            return value:GetFullName()
        end)
        if ok then name = fullName end
        return name .. " [" .. value.ClassName .. "]"
    end
    return tostring(value) .. " [" .. typeof(value) .. "]"
end

local function DescribeTransform(value)
    if typeof(value) ~= "Instance" or not value:IsA("PVInstance") then
        return ""
    end

    local ok, pivot = pcall(function()
        return value:GetPivot()
    end)
    if not ok then return " | pivot unavailable" end

    local extra = ""
    if value:IsA("Model") then
        local boxOk, boxCFrame, boxSize = pcall(function()
            return value:GetBoundingBox()
        end)
        if boxOk then
            extra = string.format(
                " | boundsCenter=(%.2f, %.2f, %.2f) boundsSize=(%.2f, %.2f, %.2f)",
                boxCFrame.Position.X, boxCFrame.Position.Y, boxCFrame.Position.Z,
                boxSize.X, boxSize.Y, boxSize.Z
            )
        end
    end

    return string.format(
        " | pivot=(%.2f, %.2f, %.2f)%s",
        pivot.Position.X, pivot.Position.Y, pivot.Position.Z, extra
    )
end

local function LogAdorneeChange(source, previous, current)
    print("[MoveHandlesAdorneeTrace] " .. source
        .. " | _Adornee: " .. Describe(previous)
        .. " -> " .. Describe(current)
        .. DescribeTransform(current))
end

local function WrappedSetAdornee(self, adornee, ...)
    SetCallCount += 1

    if adornee ~= LastHookTarget then
        SetTargetChangeCount += 1
        LastHookTarget = adornee
        LastHookTargetDescription = Describe(adornee)

        -- Print at most one target-change trace per second.
        if os.clock() - LastTraceAt >= 1 then
            LastTraceAt = os.clock()
            print("[MoveHandlesAdorneeTrace] SetAdornee target changed #"
                .. SetTargetChangeCount .. " | target=" .. LastHookTargetDescription)

            if debug and type(debug.traceback) == "function" then
                local ok, trace = pcall(debug.traceback, "[MoveHandlesAdorneeTrace] caller (sample)", 2)
                if ok then print(trace) end
            end
        end
    end

    local packed = table.pack(pcall(OriginalSetAdornee, self, adornee, ...))
    if not packed[1] then
        warn("[MoveHandlesAdorneeTrace] SetAdornee ERROR: " .. tostring(packed[2]))
        error(packed[2], 0)
    end

    return table.unpack(packed, 2, packed.n)
end

local hookOk, hookError = pcall(function()
    rawset(MoveHandles, "SetAdornee", WrappedSetAdornee)
end)

if hookOk and rawget(MoveHandles, "SetAdornee") == WrappedSetAdornee then
    HookInstalled = true
    print("[MoveHandlesAdorneeTrace] SetAdornee hook installed")
else
    warn("[MoveHandlesAdorneeTrace] Could not hook SetAdornee: " .. tostring(hookError))
    print("[MoveHandlesAdorneeTrace] Polling _Adornee only")
end

print("[MoveHandlesAdorneeTrace] Started | initial _Adornee: " .. Describe(LastAdornee))
print("[MoveHandlesAdorneeTrace] Initial SelectedBlock: " .. Describe(LastSelected))
print("[MoveHandlesAdorneeTrace] Enable GROUP MOVE / GROUP ARMED, then move/select blocks.")
print("[MoveHandlesAdorneeTrace] One status line every 5 seconds. Cleanup: MoveHandlesAdorneeTraceCleanup()")

local function Cleanup()
    if not Active then return end
    Active = false

    if HookInstalled and rawget(MoveHandles, "SetAdornee") == WrappedSetAdornee then
        pcall(function()
            rawset(MoveHandles, "SetAdornee", OriginalRawSetAdornee)
        end)
    end

    if Env.MoveHandlesAdorneeTraceCleanup == Cleanup then
        Env.MoveHandlesAdorneeTraceCleanup = nil
    end

    print("[MoveHandlesAdorneeTrace] Stopped | SetAdornee calls="
        .. SetCallCount .. " | target changes=" .. SetTargetChangeCount)
end

Env.MoveHandlesAdorneeTraceCleanup = Cleanup

task.spawn(function()
    local startedAt = os.clock()

    while Active and os.clock() - startedAt < 180 do
        task.wait(0.2)
        if not Active then break end

        local currentAdornee = rawget(MoveHandles, "_Adornee")
        if currentAdornee ~= LastAdornee then
            LogAdorneeChange("POLL", LastAdornee, currentAdornee)
            LastAdornee = currentAdornee
        end

        local currentSelected = rawget(ClientState, "SelectedBlock")
        if currentSelected ~= LastSelected then
            print("[MoveHandlesAdorneeTrace] SelectedBlock changed: "
                .. Describe(LastSelected) .. " -> " .. Describe(currentSelected))
            LastSelected = currentSelected
        end

        if os.clock() - LastReportAt >= 5 then
            LastReportAt = os.clock()
            print("[MoveHandlesAdorneeTrace] STATUS | SetAdornee calls="
                .. SetCallCount .. " | target changes=" .. SetTargetChangeCount
                .. " | current _Adornee=" .. Describe(currentAdornee)
                .. " | SelectedBlock=" .. Describe(currentSelected))
        end
    end

    if Active then
        print("[MoveHandlesAdorneeTrace] 180-second capture window ended")
        Cleanup()
    end
end)
