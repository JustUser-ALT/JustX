-- Native Move Selection Diagnostic V18 (read-only toolbar path)
local RS=game:GetService("ReplicatedStorage")
local BM=RS:WaitForChild("BuildMode")
local function log(s) print("[MoveState] "..tostring(s)) end
local function src(obj,label)
 if type(decompile)~="function" then log(label.." decompile unavailable"); return nil end
 local ok,r=pcall(decompile,obj)
 log(label.." decompile="..tostring(ok).." type="..type(r))
 if ok and type(r)=="string" then return r end
end
local function dump(obj,label,limit)
 local s=src(obj,label)
 if not s then return end
 local lines={}
 for line in string.gmatch(s,"([^\n]+)") do lines[#lines+1]=line end
 log(label.." lines="..#lines)
 local shown=0
 for i,line in ipairs(lines) do
  if string.find(line,"Mount",1,true) or string.find(line,"BuildingModeToolbar",1,true)
   or string.find(line,"BuildModeClient",1,true) or string.find(line,"Instance",1,true)
   or string.find(line,"ClientState",1,true) or string.find(line,"RenderLoop",1,true)
   or string.find(line,"function ",1,true) then
   log(label.."["..i.."] "..string.sub(line,1,220))
   shown=shown+1
   if shown>=limit then break end
  end
 end
end
log("===== TOOLBAR PATH V18 =====")
local toolbar=BM:FindFirstChild("Toolbar")
local modes=BM:FindFirstChild("Modes")
local bmt=toolbar and toolbar:FindFirstChild("BuildingModeToolbar")
if toolbar then dump(toolbar,"Toolbar",32) else log("Toolbar module missing") end
if bmt then dump(bmt,"BuildingModeToolbar",32) else log("BuildingModeToolbar module missing") end
if modes then
 local move=modes:FindFirstChild("Move")
 if move then
  local s=src(move,"Move mode")
  if s then
   local lines={}
   for line in string.gmatch(s,"([^\n]+)") do lines[#lines+1]=line end
   for i,line in ipairs(lines) do
    if string.find(line,"SelectedBlock",1,true) or string.find(line,"MoveHandles",1,true)
     or string.find(line,"function v1.",1,true) then log("MOVE["..i.."] "..string.sub(line,1,220)) end
   end
  end
 end
end
log("===== END V18 =====")
