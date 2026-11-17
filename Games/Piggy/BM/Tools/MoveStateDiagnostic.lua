-- Native Move Commit Diagnostic V27 (read-only)
local RS=game:GetService("ReplicatedStorage")
local function log(s) print("[MoveState] "..tostring(s)) end
local function decomp(obj)
 if type(decompile)~="function" then return nil end
 local ok,s=pcall(decompile,obj)
 if ok and type(s)=="string" then return s end
 return nil
end
local function linesOf(s)
 local t={}
 if type(s)=="string" then
  for line in string.gmatch(s,"([^\n]+)") do t[#t+1]=line end
 end
 return t
end
local function dumpMatches(label,obj,terms,radius)
 log("===== "..label.." =====")
 local s=decomp(obj)
 if not s then log("DECOMPILE UNAVAILABLE"); return end
 local t=linesOf(s)
 log("SOURCE LINES="..#t)
 local found={}
 for i,line in ipairs(t) do
  for _,term in ipairs(terms) do
   if string.find(line,term,1,true) then found[#found+1]=i; break end
  end
 end
 log("MATCHES="..#found)
 local shown={}
 for _,n in ipairs(found) do
  local a=math.max(1,n-radius)
  local b=math.min(#t,n+radius)
  for i=a,b do
   if not shown[i] then
    shown[i]=true
    log("L"..i.." "..string.sub(t[i],1,300))
   end
  end
 end
end
local function pathOf(obj)
 local ok,p=pcall(function() return obj:GetFullName() end)
 return ok and p or obj.Name
end
local bm=RS:FindFirstChild("BuildMode")
local bc=bm and bm:FindFirstChild("BuildModeClient")
dumpMatches("CLIENT COMMIT AND SELECTION REFERENCES",bc,{"CommitMove","RequestRealDimensions","SelectedBlock","PlaceBlockAction"},4)
log("===== RELEVANT REMOTE INSTANCES =====")
local count=0
for _,obj in ipairs(RS:GetDescendants()) do
 if obj.Name=="CommitMove" or obj.Name=="RequestRealDimensions" or string.find(obj.Name,"Commit",1,true) then
  count=count+1
  log(pathOf(obj).." <"..obj.ClassName..">")
 end
end
log("REMOTE MATCH COUNT="..count)
log("===== MODULES WITH COMMITMOVE NAME =====")
for _,obj in ipairs(RS:GetDescendants()) do
 if obj:IsA("ModuleScript") and (string.find(string.lower(obj.Name),"move",1,true) or string.find(string.lower(obj.Name),"placement",1,true)) then
  log(pathOf(obj).." <ModuleScript>")
 end
end
log("===== END V27 =====")