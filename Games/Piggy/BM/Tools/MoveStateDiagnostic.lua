-- Native Move Selection Diagnostic V20 (constructor source, read-only)
local RS=game:GetService("ReplicatedStorage")
local BM=RS:WaitForChild("BuildMode")
local function log(s) print("[MoveState] "..tostring(s)) end
local function source(obj,label)
 if type(decompile)~="function" then log(label.." decompile unavailable"); return nil end
 local ok,r=pcall(decompile,obj)
 log(label.." decompile="..tostring(ok).." type="..type(r))
 if ok and type(r)=="string" then return r end
end
local function show(obj,label,first,last)
 local s=source(obj,label)
 if not s then return end
 local lines={}
 for line in string.gmatch(s,"([^\n]+)") do lines[#lines+1]=line end
 log(label.." total lines="..#lines)
 for i=first,math.min(last,#lines) do log(label.."["..i.."] "..string.sub(lines[i],1,240)) end
end
log("===== CONSTRUCTOR SOURCE V20 =====")
local bc=BM:FindFirstChild("BuildModeClient")
if bc then
 show(bc,"BuildModeClient",1,175)
 show(bc,"BuildModeClient",175,360)
end
local tb=BM:FindFirstChild("Toolbar")
if tb then
 show(tb,"Toolbar",205,270)
end
local bmt=BM:FindFirstChild("BuildingModeToolbar")
if bmt then
 show(bmt,"BuildingModeToolbar",45,75)
end
log("===== END V20 =====")
