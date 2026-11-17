-- Native Move Selection Diagnostic V23 (compare LocalScript and executor globals, read-only)
local Players=game:GetService("Players")
local function log(s) print("[MoveState] "..tostring(s)) end
local function safe(fn)
 local ok,value=pcall(fn)
 return ok,value
end
local function desc(v)
 if v==nil then return "nil" end
 local t=typeof(v)
 if t=="Instance" then
  local ok,path=pcall(function() return v:GetFullName() end)
  return "Instance "..(ok and path or v.Name)
 end
 return t
end
log("===== GLOBAL ENVIRONMENT DIAGNOSTIC V23 =====")
local main=Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui"):FindFirstChild("Main")
log("Main="..desc(main))
local env
if type(getsenv)=="function" and main then
 local ok,value=safe(function() return getsenv(main) end)
 log("getsenv(Main) ok="..tostring(ok).." type="..desc(value))
 if ok then env=value end
else
 log("getsenv unavailable")
end
local function inspect(label,tab)
 log(label.." type="..desc(tab))
 if type(tab)=="table" then
  local ok,value=safe(function() return tab.BuildModeClient end)
  log(label..".BuildModeClient read="..tostring(ok).." value="..desc(value))
  local count=0
  for k,v in pairs(tab) do
   local s=tostring(k)
   if string.find(string.lower(s),"build",1,true) or string.find(string.lower(s),"client",1,true) then
    count=count+1
    log(label.." key "..s.."="..desc(v))
   end
  end
  log(label.." matching keys="..count)
 end
end
if type(env)=="table" then
 local ok,scriptG=safe(function() return env._G end)
 log("MainEnv._G read="..tostring(ok).." value="..desc(scriptG))
 inspect("MainEnv",env)
 if ok then inspect("MainEnv._G",scriptG) end
 local ok2,v16=safe(function() return env.v16 end)
 log("MainEnv.v16 read="..tostring(ok2).." value="..desc(v16))
end
inspect("Executor _G",_G)
if type(getgenv)=="function" then
 local ok,g=safe(function() return getgenv() end)
 log("getgenv() ok="..tostring(ok).." value="..desc(g))
 if ok then inspect("getgenv()",g) end
else
 log("getgenv unavailable")
end
log("No properties assigned; no methods called")
log("===== END V23 =====")
