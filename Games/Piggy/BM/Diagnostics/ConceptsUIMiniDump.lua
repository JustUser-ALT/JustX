-- Concepts UI mini-diagnostic v2 (read-only)
local P = game:GetService("Players").LocalPlayer
local roots = {P:WaitForChild("PlayerGui"), game:GetService("CoreGui")}
local keys = {"grid","divider","multi","select","snap","step","increment","move","resize","rotate"}
local lines = {}
local seen = {}
local function add(s)
    if #lines < 40 then lines[#lines + 1] = tostring(s) end
end
local function txt(o)
    if o:IsA("TextBox") or o:IsA("TextButton") or o:IsA("TextLabel") then return o.Text end
    return ""
end
local function match(o)
    if o:IsA("TextBox") then return "TEXTBOX" end
    if o:IsA("TextButton") or o:IsA("ImageButton") or o:IsA("TextLabel") then
        local s = (o.Name .. " " .. txt(o)):lower()
        for _, k in ipairs(keys) do
            if s:find(k, 1, true) then return "MATCH:" .. k end
        end
    end
end
local function desc(o)
    return o.ClassName .. " " .. o.Name .. " Text=" .. string.format("%q", txt(o))
end
add("CONCEPTS MINI DUMP v2 | PlaceId=" .. game.PlaceId)
for _, root in ipairs(roots) do
    local ok, all = pcall(root.GetDescendants, root)
    if ok then
        for _, o in ipairs(all) do
            local why = match(o)
            if why and not seen[o] then
                seen[o] = true
                add(why .. " | " .. desc(o))
                if o.Parent and o.Parent ~= root then add("  PARENT | " .. desc(o.Parent)) end
                if o.Parent and o.Parent.Parent and o.Parent.Parent ~= root then
                    add("  GRANDPARENT | " .. desc(o.Parent.Parent))
                end
                if #lines >= 37 then break end
            end
        end
    end
    if #lines >= 37 then break end
end
add("END | listed up to 37 records")
local report = table.concat(lines, "\n")
if type(setclipboard) == "function" then pcall(setclipboard, report) end
warn(report)
print("[ConceptsMiniDump] Done. This script emits at most 40 lines.")
