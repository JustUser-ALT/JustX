-- Native Move Flow Diagnostic V29 (read-only source inspection)
local RS=game:GetService("ReplicatedStorage")
local function log(s) print("[MoveState] "..tostring(s)) end
local function get(obj)
 if not obj or type(decompile)~="function" then return nil end
 local ok,s=pcall(decompile,obj)
 if ok and type(s)=="string" then return s end
 return nil
end
local function dumpRange(label,obj,a,b)
 log("===== "..label.." =====")
 local s=get(obj)
 if not s then log("SOURCE UNAVAILABLE"); return end
 local t={}
 for line in string.gmatch(s,"([^\n]+)") do t[#t+1]=line end
 log("SOURCE LINES="..#t)
 for i=math.max(1,a),math.min(#t,b) do log("L"..i.." "..string.sub(t[i],1,270)) end
end
local bm=RS:FindFirstChild("BuildMode")
local bc=bm and bm:FindFirstChild("BuildModeClient")
dumpRange("LINK/CLONE HANDOFF FULL",bc,790,845)
dumpRange("BUILD MODE PLACEMENT SOURCE",bm and bm:FindFirstChild("Placement"),1,326)
dumpRange("BUILD MODE PLACEMENT LOGIC SOURCE",bm and bm:FindFirstChild("PlacementLogic"),1,159)
dumpRange("REPLICATED PLACEMENT SOURCE",RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Placement"),1,156)
log("===== REMOTE CLASS AND ATTRIBUTES =====")
local funcs=RS:FindFirstChild("Functions")
if funcs then
 for _,name in ipairs({"CommitMove","RequestRealDimensions","UpdateBlockLink"}) do
  local obj=funcs:FindFirstChild(name)
  if obj then
   log(name.." class="..obj.ClassName.." full="..obj:GetFullName())
   for k,v in pairs(obj:GetAttributes()) do log(name.." attr "..k.."="..tostring(v)) end
  else log(name.." MISSING") end
 end
else log("ReplicatedStorage.Functions MISSING") end
log("===== END V29 =====")