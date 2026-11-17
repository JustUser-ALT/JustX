-- Native Move Selection Diagnostic V24 (inspect actual Main-owned BuildModeClient, read-only)
local Players=game:GetService("Players")
local function log(s) print("[MoveState] "..tostring(s)) end
local function safeGet(obj,key)
 local ok,value=pcall(function() return obj[key] end)
 return ok,value
end
local function desc(v)
 if v==nil then return "nil" end
 local t=typeof(v)
 if t=="Instance" then
  local ok,path=pcall(function() return v:GetFullName() end)
  return "Instance "..(ok and path or v.Name).." <"..v.ClassName..">"
 end
 return t
end
log("===== LIVE MAIN-OWNED CLIENT STATE V24 =====")
local player=Players.LocalPlayer
local gui=player:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui")
local main=gui:FindFirstChild("Main")
if not main or type(getsenv)~="function" then
 log("STOP: Main or getsenv unavailable")
 return
end
local okEnv,env=pcall(getsenv,main)
log("getsenv(Main) ok="..tostring(okEnv).." type="..desc(env))
if not okEnv or type(env)~="table" then return end
local okG,g=pcall(function() return env._G end)
log("MainEnv._G ok="..tostring(okG).." type="..desc(g))
if not okG or type(g)~="table" then return end
local okState,state=pcall(function() return g.BuildModeClient end)
log("MainEnv._G.BuildModeClient ok="..tostring(okState).." type="..desc(state))
if not okState or type(state)~="table" then
 log("STOP: live state unavailable")
 return
end
local keys={}
for k,v in pairs(state) do keys[#keys+1]=tostring(k).."="..desc(v) end
table.sort(keys)
log("RAW STATE FIELDS count="..#keys)
for _,entry in ipairs(keys) do log(entry) end
for _,name in ipairs({"SelectedBlock","MoveHandles","BoxSelection","ResizeHandles","Placement","Toolbar","EditorMode","ScreenGui"}) do
 local ok,value=safeGet(state,name)
 log("FIELD "..name.." read="..tostring(ok).." value="..desc(value))
 if (name=="MoveHandles" or name=="BoxSelection" or name=="ResizeHandles") and ok and value~=nil then
  local okA,a=safeGet(value,"_Adornee")
  log(name.."._Adornee read="..tostring(okA).." value="..desc(a))
 end
end
local okToolbar,toolbar=safeGet(state,"Toolbar")
if okToolbar and toolbar~=nil then
 local okInner,inner=safeGet(toolbar,"BuildingModeToolbar")
 log("Toolbar.BuildingModeToolbar read="..tostring(okInner).." value="..desc(inner))
 if okInner and inner~=nil then
  local okOwner,owner=safeGet(inner,"BuildModeClient")
  log("Toolbar.BuildingModeToolbar.BuildModeClient read="..tostring(okOwner).." value="..desc(owner))
  log("GLOBAL_EQUALS_TOOLBAR_OWNER "..tostring(owner==state))
 end
end
log("READ-ONLY: no properties assigned and no methods called")
log("===== END V24 =====")
