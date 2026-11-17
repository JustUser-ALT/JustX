-- Native Move Selection Diagnostic V16 (read-only Main source)
local Players=game:GetService("Players")
local gui=Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("BuildModeGui")
local main=gui and gui:FindFirstChild("Main")
local n,LIMIT=0,100
local function log(s)
 if n>=LIMIT then return end
 n=n+1
 print("[MoveState] "..tostring(s))
end
local function describe(v)
 if typeof(v)=="Instance" then
  local ok,p=pcall(function() return v:GetFullName() end)
  return (ok and p or v.Name).." <"..v.ClassName..">"
 end
 return type(v).." "..tostring(v)
end
log("===== MAIN SOURCE DIAGNOSTIC V16 =====")
log("Main="..describe(main))
if not main or not main:IsA("LocalScript") then log("Main missing"); return end
if type(getsenv)=="function" then
 local ok,env=pcall(getsenv,main)
 log("getsenv="..tostring(ok))
 if ok and type(env)=="table" then
  local count=0
  for k,v in pairs(env) do
   count=count+1
   if count<=35 then log("ENV["..tostring(k).."]="..describe(v)) end
  end
  log("ENV key count="..count)
 end
end
local source
if type(decompile)=="function" then
 local ok,result=pcall(decompile,main)
 log("decompile="..tostring(ok).." type="..type(result))
 if ok and type(result)=="string" then source=result end
elseif type(getscriptsource)=="function" then
 local ok,result=pcall(getscriptsource,main)
 log("getscriptsource="..tostring(ok).." type="..type(result))
 if ok and type(result)=="string" then source=result end
else
 log("No decompile/getscriptsource")
end
if source then
 local lines={}
 for line in string.gmatch(source,"([^\n]+)") do lines[#lines+1]=line end
 log("SOURCE lines="..#lines)
 local shown=0
 for i,line in ipairs(lines) do
  local low=string.lower(line)
  if string.find(low,"buildmodeclient") or string.find(low,"clientstate") or string.find(low,":mount")
   or string.find(low,".new(") or string.find(low,"buildingmodetoolbar") or string.find(low,"renderloop") then
   log("SRC["..i.."] "..string.sub(line,1,220))
   shown=shown+1
   if shown>=35 then break end
  end
 end
 if shown==0 then log("No relevant source lines matched") end
end
log("===== END V16 =====")
