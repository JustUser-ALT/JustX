-- Native Move Selection Diagnostic V17 (read-only source inspection)
local RS=game:GetService("ReplicatedStorage")
local function log(s) print("[MoveState] "..tostring(s)) end
local function getSource(target,label)
 if type(decompile)~="function" then log(label..": decompile unavailable"); return nil end
 local ok,result=pcall(decompile,target)
 log(label.." decompile="..tostring(ok).." type="..type(result))
 if ok and type(result)=="string" then return result end
 return nil
end
log("===== SOURCE INSPECTION V17 =====")
local gui=game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("BuildModeGui")
local main=gui and gui:FindFirstChild("Main")
local mainSource=main and getSource(main,"Main")
if mainSource then
 local lines={}
 for line in string.gmatch(mainSource,"([^\n]+)") do lines[#lines+1]=line end
 log("Main lines="..#lines)
 for i=1,math.min(#lines,42) do log("MAIN["..i.."] "..string.sub(lines[i],1,220)) end
end
local module=RS:FindFirstChild("BuildMode") and RS.BuildMode:FindFirstChild("BuildModeClient")
if module then
 local moduleSource=getSource(module,"BuildModeClient module")
 if moduleSource then
  local lines={}
  for line in string.gmatch(moduleSource,"([^\n]+)") do lines[#lines+1]=line end
  log("BuildModeClient lines="..#lines)
  local starts={}
  for i,line in ipairs(lines) do
   if string.find(line,"function ",1,true) and (string.find(line,"Mount",1,true) or string.find(line,"Destroy",1,true)) then
    starts[#starts+1]=i
   end
  end
  for _,start in ipairs(starts) do
   log("---- module around line "..start.." ----")
   for i=math.max(1,start-2),math.min(#lines,start+22) do log("BC["..i.."] "..string.sub(lines[i],1,220)) end
  end
 end
else
 log("BuildModeClient module missing")
end
log("===== END V17 =====")
