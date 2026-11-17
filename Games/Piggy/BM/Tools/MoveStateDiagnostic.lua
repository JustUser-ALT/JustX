-- Native Move Selection Diagnostic V21 (constructor tail and owner references, read-only)
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local BM=RS:WaitForChild("BuildMode")
local function log(s) print("[MoveState] "..tostring(s)) end
local function getSource(obj)
 if type(decompile)~="function" then return nil end
 local ok,r=pcall(decompile,obj)
 if ok and type(r)=="string" then return r end
end
local function lines(s)
 local t={}
 for line in string.gmatch(s or "","([^\n]+)") do t[#t+1]=line end
 return t
end
log("===== CONSTRUCTOR TAIL V21 =====")
local bc=BM:FindFirstChild("BuildModeClient")
if bc then
 local t=lines(getSource(bc))
 log("BuildModeClient lines="..#t)
 for i=math.max(1,#t-52),#t do log("BC["..i.."] "..string.sub(t[i],1,220)) end
end
local main=Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BuildModeGui"):FindFirstChild("Main")
if main then
 local t=lines(getSource(main))
 log("Main source lines="..#t)
 local hits={}
 for i,line in ipairs(t) do
  local low=string.lower(line)
  if string.find(low,"buildmodeclient",1,true) or string.find(low,".new(",1,true) or string.find(low,":mount(",1,true) then
   hits[#hits+1]=i
  end
 end
 log("Main relevant lines="..#hits)
 for _,i in ipairs(hits) do
  for j=math.max(1,i-2),math.min(#t,i+3) do log("Main["..j.."] "..string.sub(t[j],1,220)) end
 end
 local envfn=getsenv
 if type(envfn)=="function" then
  local ok,env=pcall(envfn,main)
  log("Main getsenv="..tostring(ok).." type="..type(env))
  if ok and type(env)=="table" then
   local count=0
   for k,v in pairs(env) do
    local key=tostring(k)
    local low=string.lower(key)
    if string.find(low,"build",1,true) or string.find(low,"client",1,true) or string.find(low,"state",1,true) or string.find(low,"gui",1,true) then
     count=count+1
     local desc=typeof(v)
     if type(v)=="table" then
      local keys={}
      for a,b in pairs(v) do
       if #keys>=8 then break end
       keys[#keys+1]=tostring(a).."="..typeof(b)
      end
      desc=desc.." {"..table.concat(keys,",").."}"
     end
     log("ENV "..key.." type="..desc)
    end
   end
   log("Main env relevant count="..count)
  end
 end
end
log("===== END V21 =====")
