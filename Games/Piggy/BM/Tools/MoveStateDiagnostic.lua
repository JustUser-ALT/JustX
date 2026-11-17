-- Native Move Selection Diagnostic V22 (live global state inspection, read-only)
local function log(s)
 print("[MoveState] "..tostring(s))
end
local function safeGet(obj,key)
 local ok,value=pcall(function() return obj[key] end)
 if ok then return value,true end
 return value,false
end
local function describe(value)
 if value==nil then return "nil" end
 local kind=typeof(value)
 if kind=="Instance" then
  local ok,path=pcall(function() return value:GetFullName() end)
  return kind.." "..(ok and path or value.Name).." <"..value.ClassName..">"
 end
 return kind
end
log("===== LIVE CLIENT STATE V22 =====")
local state=_G and _G.BuildModeClient
log("_G.BuildModeClient = "..describe(state))
if type(state)~="table" then
 log("STOP: global state is not a table; no changes made")
 log("===== END V22 =====")
 return
end
local keys={}
for k,v in pairs(state) do
 keys[#keys+1]=tostring(k).."="..describe(v)
end
table.sort(keys)
log("RAW STATE FIELDS ("..#keys..")")
for _,entry in ipairs(keys) do log(entry) end
local fields={"SelectedBlock","MoveHandles","BoxSelection","ResizeHandles","Placement","Toolbar","EditorMode","ScreenGui"}
for _,name in ipairs(fields) do
 local value,ok=safeGet(state,name)
 log("FIELD "..name.." read="..tostring(ok).." value="..describe(value))
 if name=="SelectedBlock" and value~=nil then
  local parent,parentOk=safeGet(value,"Parent")
  log("SelectedBlock.Parent read="..tostring(parentOk).." value="..describe(parent))
 end
 if name=="MoveHandles" or name=="BoxSelection" or name=="ResizeHandles" then
  local adornee,adorneeOk=safeGet(value,"_Adornee")
  log(name.."._Adornee read="..tostring(adorneeOk).." value="..describe(adornee))
 end
end
local toolbar,toolbarOk=safeGet(state,"Toolbar")
if toolbarOk and toolbar~=nil then
 local inner,innerOk=safeGet(toolbar,"BuildingModeToolbar")
 log("Toolbar.BuildingModeToolbar read="..tostring(innerOk).." value="..describe(inner))
 if innerOk and inner~=nil then
  local owner,ownerOk=safeGet(inner,"BuildModeClient")
  log("Toolbar.BuildingModeToolbar.BuildModeClient read="..tostring(ownerOk).." value="..describe(owner))
  log("GLOBAL_EQUALS_TOOLBAR_OWNER "..tostring(owner==state))
 end
end
log("READ-ONLY CHECK: no properties assigned, no methods called")
log("===== END V22 =====")
