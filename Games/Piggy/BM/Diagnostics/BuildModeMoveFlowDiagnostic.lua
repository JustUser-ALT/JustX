--==================================================
-- BUILD MODE CLIENT MOVE FLOW DIAGNOSTIC
-- Read-only source inspection. Does not modify BuildMode.
--==================================================

local RS = game:GetService("ReplicatedStorage")
local BuildMode = RS:WaitForChild("BuildMode")
local ClientModule = BuildMode:WaitForChild("BuildModeClient")

local function Log(...)
    print("[BuildModeMoveFlow]", ...)
end

if type(decompile) ~= "function" then
    Log("decompile unavailable")
    return
end

local ok, source = pcall(decompile, ClientModule)
if not ok or type(source) ~= "string" then
    Log("BuildModeClient decompile failed:", source)
    return
end

local lines = string.split(source, "\n")
Log("Source lines:", #lines)

local patterns = {
    "DraggingContext",
    "MoveHandles",
    "SelectedBlock",
    "MouseButton1Down",
    "MouseButton1Up",
    "MouseDrag",
    "CommitMove",
    "PlaceBlockAction"
}

local selected = {}
for lineIndex, line in ipairs(lines) do
    for _, pattern in ipairs(patterns) do
        if string.find(line, pattern, 1, true) then
            for contextIndex = math.max(1, lineIndex - 7), math.min(#lines, lineIndex + 12) do
                selected[contextIndex] = true
            end
            break
        end
    end
end

local lastPrinted = 0
for lineIndex = 1, #lines do
    if selected[lineIndex] then
        if lineIndex > lastPrinted + 1 then
            Log("...")
        end
        Log(string.format("%04d", lineIndex), lines[lineIndex])
        lastPrinted = lineIndex
    end
end

Log("========== END; SOURCE EXCERPTS ONLY ==========")
