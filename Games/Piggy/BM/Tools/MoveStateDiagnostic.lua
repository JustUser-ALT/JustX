-- Native Move Selection Diagnostic V25 (inspect mode dispatch and selection handlers, read-only)
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local function log(s) print("[MoveState] "..tostring(s)) end
local function lines(s)
 local t={}
 for line in string.gmatch(s or "","([^\n]+)") do t[#t+1]=line end
 return t
end
local function source(obj)
 if type(decompile)~="function" then return nil end
 local ok,s=pcall(decompile,obj)
 if ok and type(s)=="string" then return s end
end
local function dump(label,obj,terms,maxHits,context)
 log("===== "..label.." =====")
 if not obj then log("MISSING"); return end
 local t=lines(source(obj))
 log("SOURCE LINES="..#t)
 local hits={}
 for i,line in ipairs(t) do
  local low=string.lower(line)
  for _,term in ipairs(terms) do
   if string.find(low,string.lower(term),1,true) then
    hits[#hits+1]=i
    break
   end
  end
 end
 log("MATCHES="..#hits)
 local shown=0
 local emitted={}
 for _,i in ipairs(hits) do
  if shown>=maxHits then break end
  local from=math.max(1,i-context)
  local to=math.min(#t,i+context)
  local fresh=false
  for n=from,to do if not emitted[n] then fresh=true end end
  if fresh then
   shown=shown+1
   log("-- MATCH "..i.." --")
   for n=from,to do
    if not emitted[n] then
     emitted[n]=true
     log("L"..n.." "..string.sub(t[n],1,240))
    end
   end
  end
 end
end
log("===== MODE / SELECTION FLOW V25 =====")
local bm=RS:WaitForChild("BuildMode")
local modes=bm:FindFirstChild("Modes")
if modes then
 dump("MOVE MODE",modes:FindFirstChild("Move"),{"function v1.action","selectedblock","movehandles:setadornee","boxselection:setadornee"},12,3)
end
dump("BUILDING MODE MODULE",bm:FindFirstChild("BuildingMode"),{"function","setmode","get","stack","settoprevious"},16,3)
dump("BUILDMODECLIENT SELECTION/MODE",bm:FindFirstChild("BuildModeClient"),{"selectedblock","setmode","buildingmodechanged","setadornee","action"},24,2)
local main=Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui"):FindFirstChild("Main")
if main then dump("MAIN MODE INITIALIZATION",main,{"setmode","buildingmode.none","buildmodeclient"},10,2) end
log("READ-ONLY: decompile only; no state changes")
log("===== END V25 =====")
