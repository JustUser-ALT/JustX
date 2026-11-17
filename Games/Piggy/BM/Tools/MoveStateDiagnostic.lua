-- Native Move Selection Diagnostic v10 (read-only)
-- Broad GC scan; all object fields are inspected without invoking __index.

local Players = game:GetService("Players")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")

local count, LIMIT = 0, 160
local function log(v)
    if count >= LIMIT then return end
    count += 1
    print("[MoveState] " .. tostring(v))
end

local function raw(t, k)
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(rawget, t, k)
    return ok and v or nil
end

local function desc(v)
    if typeof(v) == "Instance" then
        local ok, p = pcall(function() return v:GetFullName() end)
        return (ok and p or v.Name) .. " <" .. v.ClassName .. ">"
    end
    if type(v) == "table" then return "table" .. (getmetatable(v) and " [mt]" or "") end
    return tostring(v) .. " <" .. typeof(v) .. ">"
end

local function keys(t, limit)
    local out, n = {}, 0
    if type(t) == "table" then
        for k, v in pairs(t) do
            n += 1
            if n <= limit then
                out[#out + 1] = tostring(k) .. ":" .. typeof(v)
            end
        end
    end
    return #out > 0 and table.concat(out, " | ") or "(no raw keys)"
end

log("===== CLIENTSTATE GC SCAN V10 =====")
log("GUI=" .. gui:GetFullName())

if not debug or type(debug.getgc) ~= "function" then
    log("debug.getgc unavailable")
else
    local ok, objects = pcall(debug.getgc, true)
    log("getgc ok=" .. tostring(ok) .. " type=" .. typeof(objects))
    if ok and type(objects) == "table" then
        local total, candidates = 0, 0
        for _, obj in pairs(objects) do
            if type(obj) == "table" then
                total += 1
                local mt = getmetatable(obj)
                local idx = type(mt) == "table" and raw(mt, "__index") or nil
                local hasSelected = raw(obj, "SelectedBlock") ~= nil
                local hasMove = raw(obj, "MoveHandles") ~= nil
                local hasToolbar = raw(obj, "Toolbar") ~= nil
                local hasBox = raw(obj, "BoxSelection") ~= nil
                local indexHasSelected = type(idx) == "table" and raw(idx, "SelectedBlock") ~= nil
                local score = (hasSelected and 1 or 0) + (hasMove and 1 or 0)
                    + (hasToolbar and 1 or 0) + (hasBox and 1 or 0)
                    + (indexHasSelected and 1 or 0)
                if score > 0 then
                    candidates += 1
                    log("CANDIDATE #" .. candidates .. " score=" .. score
                        .. " rawKeys={" .. keys(obj, 18) .. "}")
                    log("  SelectedBlock=" .. desc(raw(obj, "SelectedBlock")))
                    log("  MoveHandles=" .. desc(raw(obj, "MoveHandles")))
                    log("  BoxSelection=" .. desc(raw(obj, "BoxSelection")))
                    log("  Toolbar=" .. desc(raw(obj, "Toolbar")))
                    log("  metatable.__index=" .. desc(idx))
                    if type(idx) == "table" then
                        log("  indexKeys={" .. keys(idx, 18) .. "}")
                    end
                end
            end
        end
        log("GC tables scanned=" .. total .. " candidates=" .. candidates)
    end
end
log("===== END =====")
