-- Native Move Server Validation Diagnostic V28 (read-only)
local RS=game:GetService("ReplicatedStorage")
local function log(s) print("[MoveState] "..tostring(s)) end
local function src(obj)
 if type(decompile)~="function" then return nil end
 local ok,s=pcall(decompile,obj)
 if ok and type(s)=="string" then return s end
 return nil
end
local function dump(label,obj,terms,radius)
 log("===== "..label.." =====")
 if not obj then log("OBJECT MISSING"); return end
 local s=src(obj)
 if not s then log("DECOMPILE UNAVAILABLE "..obj:GetFullName()); return end
 local t={}
 for line in string.gmatch(s,"([^\n]+)") do t[#t+1]=line end
 log("SOURCE LINES="..#t)
 local matches={}
 for i,line in ipairs(t) do
  for _,term in ipairs(terms) do
   if string.find(line,term,1,true) then matches[#matches+1]=i; break end
  end
 end
 log("MATCHES="..#matches)
 local shown={}
 for _,n in ipairs(matches) do
  for i=math.max(1,n-radius),math.min(#t,n+radius) do
   if not shown[i] then shown[i]=true; log("L"..i.." "..string.sub(t[i],1,280)) end
  end
 end
end
local bm=RS:FindFirstChild("BuildMode")
local bc=bm and bm:FindFirstChild("BuildModeClient")
dump("CLIENT LINK AND CLONE FLOW",bc,{"UpdateBlockLink","SelectedBlock","SetMode"},3)
dump("BUILD MODE PLACEMENT",bm and bm:FindFirstChild("Placement"),{"CommitMove","CommitResize","SelectedBlock","PivotTo"},5)
dump("BUILD MODE PLACEMENT LOGIC",bm and bm:FindFirstChild("PlacementLogic"),{"CommitMove","CommitResize","SelectedBlock","PivotTo"},5)
dump("REPLICATED PLACEMENT",RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Placement"),{"CommitMove","CommitResize","PivotTo","BuildModel"},5)
log("===== SERVER SCRIPT REMOTE REFERENCES =====")
local roots={}
for _,name in ipairs({"ServerScriptService","ServerStorage"}) do
 local root=game:GetService(name)
 if root then roots[#roots+1]=root end
end
local scanned,matched=0,0
for _,root in ipairs(roots) do
 for _,obj in ipairs(root:GetDescendants()) do
  if obj:IsA("Script") or obj:IsA("ModuleScript") then
   scanned=scanned+1
   local s=src(obj)
   if s and (string.find(s,"CommitMove",1,true) or string.find(s,"RequestRealDimensions",1,true)) then
    matched=matched+1
    log("SERVER MATCH "..obj:GetFullName())
    local t={}
    for line in string.gmatch(s,"([^\n]+)") do t[#t+1]=line end
    local shown={}
    for i,line in ipairs(t) do
     if string.find(line,"CommitMove",1,true) or string.find(line,"RequestRealDimensions",1,true) then
      for j=math.max(1,i-5),math.min(#t,i+9) do
       if not shown[j] then shown[j]=true; log("L"..j.." "..string.sub(t[j],1,260)) end
      end
     end
    end
   end
  end
 end
end
log("SERVER SCANNED="..scanned.." MATCHED="..matched)
log("===== END V28 =====")