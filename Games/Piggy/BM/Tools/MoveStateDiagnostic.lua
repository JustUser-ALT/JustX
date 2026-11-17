-- Native Move Selection Diagnostic V19 (read-only component wiring)
local RS=game:GetService("ReplicatedStorage")
local BM=RS:WaitForChild("BuildMode")
local function log(s) print("[MoveState] "..tostring(s)) end
local function decomp(obj,label)
 if type(decompile)~="function" then log(label.." decompile unavailable"); return nil end
 local ok,r=pcall(decompile,obj)
 log(label.." decompile="..tostring(ok).." type="..type(r))
 if ok and type(r)=="string" then return r end
end
local function linesOf(s)
 local t={}
 for line in string.gmatch(s,"([^\n]+)") do t[#t+1]=line end
 return t
end
log("===== COMPONENT WIRING V19 =====")
local toolbar=BM:FindFirstChild("Toolbar")
if toolbar then
 local t=linesOf(decomp(toolbar,"Toolbar") or "")
 log("Toolbar source lines="..#t)
 local ranges={{1,45},{180,270},{270,390},{390,482}}
 for _,range in ipairs(ranges) do
  log("-- Toolbar lines "..range[1].."-"..range[2].." --")
  for i=range[1],math.min(range[2],#t) do
   local line=t[i]
   if line and (string.find(line,"BuildModeClient",1,true) or string.find(line,"function ",1,true)
    or string.find(line,"new(",1,true) or string.find(line,"Mount",1,true)
    or string.find(line,"BuildingModeToolbar",1,true) or string.find(line,"return ",1,true)) then
    log("TB["..i.."] "..string.sub(line,1,220))
   end
  end
 end
else log("Toolbar missing") end
local found={}
for _,obj in ipairs(BM:GetDescendants()) do
 if obj:IsA("ModuleScript") and string.find(string.lower(obj.Name),"buildingmodetoolbar",1,true) then
  found[#found+1]=obj
 end
end
log("BuildingModeToolbar modules found="..#found)
for _,obj in ipairs(found) do
 local ok,p=pcall(function() return obj:GetFullName() end)
 log("MODULE "..(ok and p or obj.Name))
 local s=decomp(obj,"BuildingModeToolbar")
 if s then
  local t=linesOf(s)
  log("BMT source lines="..#t)
  for i,line in ipairs(t) do
   if string.find(line,"function ",1,true) or string.find(line,"BuildModeClient",1,true)
    or string.find(line,"return ",1,true) or string.find(line,"Mount",1,true) then
    log("BMT["..i.."] "..string.sub(line,1,220))
   end
  end
 end
end
log("===== END V19 =====")
