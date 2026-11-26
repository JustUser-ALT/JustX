-- ResizeCommitProbe.lua
-- Temporary diagnostic: logs the real CommitResize arguments during one native resize.
-- Start this script, resize one block slightly with the normal Piggy Resize tool, then release.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommitResize = ReplicatedStorage:WaitForChild("Functions"):WaitForChild("CommitResize")

if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
    warn("[ResizeCommitProbe] This executor does not expose hookmetamethod/getnamecallmethod")
    return
end

if _G.__ResizeCommitProbeInstalled then
    _G.__ResizeCommitProbeActive = true
    warn("[ResizeCommitProbe] Existing probe re-armed. Resize one block now.")
    return
end

_G.__ResizeCommitProbeInstalled = true
_G.__ResizeCommitProbeActive = true

local function describe(value, depth)
    depth = depth or 0
    local kind = typeof(value)

    if kind == "Instance" then
        return value:GetFullName() .. " [" .. value.ClassName .. "]"
    elseif kind == "Vector3" then
        return string.format("Vector3(%.6f, %.6f, %.6f)", value.X, value.Y, value.Z)
    elseif kind == "CFrame" then
        local p = value.Position
        return string.format("CFrame(pos=%.6f, %.6f, %.6f)", p.X, p.Y, p.Z)
    elseif type(value) ~= "table" then
        return tostring(value) .. " [" .. kind .. "]"
    end

    if depth >= 4 then
        return "{...}"
    end

    local output = "{"
    local count = 0
    for key, item in pairs(value) do
        count += 1
        if count > 40 then
            output ..= ", ..."
            break
        end
        output ..= string.format("\n%s[%s] = %s", string.rep("  ", depth + 1), tostring(key), describe(item, depth + 1))
    end
    return output .. "\n" .. string.rep("  ", depth) .. "}"
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()

    if _G.__ResizeCommitProbeActive
        and self == CommitResize
        and method == "InvokeServer" then

        _G.__ResizeCommitProbeActive = false

        local args = table.pack(...)
        print("[ResizeCommitProbe] ===== CommitResize captured =====")
        print("[ResizeCommitProbe] Argument count:", args.n)

        for index = 1, args.n do
            print("[ResizeCommitProbe] arg[" .. index .. "] = " .. describe(args[index]))
        end

        print("[ResizeCommitProbe] ===== Capture complete =====")
    end

    return oldNamecall(self, ...)
end))

print("[ResizeCommitProbe] Armed. Now resize ONE block slightly using the normal Resize tool and release the handle.")
