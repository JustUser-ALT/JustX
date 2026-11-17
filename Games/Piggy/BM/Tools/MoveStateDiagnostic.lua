-- Native Move Selection Diagnostic V15 (read-only, Main environment)
local RS=game:GetService("ReplicatedStorage")
local root=RS:WaitForChild("BuildMode")
local Players=game:GetService("Players")
local count,LIMIT=0,100
local function log(s)
    if count>=LIMIT then return end
    count=count+1
    print("[MoveState] "..tostring(s))
end
local function desc(v)
    if typeof(v)=="Instance" then
        local ok,n=pcall(function() return v:GetFullName() end)
        return (ok and n or v.Name).." <"..v.ClassName..">"
    end
    if type(v)=="table" then return "table" end
    return type(v).." "..tostring(v)
end
local function inspect(label,t)
    if type(t)~="table" then log(label.." not table: "..desc(t)); return end
    local keys={}
    for k,v in pairs(t) do
        local s=tostring(k)
        if string.find(string.lower(s),"build") or string.find(string.lower(s),"client")
        or string.find(string.lower(s),"state") or string.find(string.lower(s),"tool")
        or string.find(string.lower(s),"select") or string.find(string.lower(s),"mode")
        or string.find(string.lower(s),"render") then
            keys[#keys+1]={k,v}
        end
    end
    table.sort(keys,function(a,b) return tostring(a[1])<tostring(b[1]) end)
    for _,pair in ipairs(keys) do
        log(label.."."..tostring(pair[1]).."="..desc(pair[2]))
        if type(pair[2])=="table" then
            for _,wanted in ipairs({"SelectedBlock","MoveHandles","BoxSelection","Toolbar","BuildingModeToolbar","Placement","ClientState"}) do
                local ok,v=pcall(function() return rawget(pair[2],wanted) end)
                if ok and v~=nil then log(label.."."..tostring(pair[1]).."."..wanted.."="..desc(v)) end
            end
        end
    end
end
log("===== MAIN ENVIRONMENT DIAGNOSTIC V15 =====")
local gui=Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("BuildModeGui")
local main=gui and gui:FindFirstChild("Main")
log("GUI Main="..desc(main))
if main and main:IsA("LocalScript") then
    log("Main Disabled="..tostring(main.Disabled))
    if type(getsenv)=="function" then
        local ok,env=pcall(getsenv,main)
        log("getsenv success="..tostring(ok).." env="..desc(env))
        if ok then inspect("ENV",env) end
    else
        log("getsenv unavailable")
    end
else
    log("Main LocalScript missing")
end
local ok,client=pcall(require,root:WaitForChild("BuildModeClient"))
if ok and type(client)=="table" and type(client.new)=="function" and debug and type(debug.getupvalues)=="function" then
    local uok,ups=pcall(debug.getupvalues,client.new)
    if uok and type(ups)=="table" then
        for i=16,33 do
            local v=ups[i]
            if v~=nil then
                log("BuildModeClient.new U"..i.."="..desc(v))
                if type(v)=="table" then inspect("U"..i,v) end
            end
        end
    else log("constructor upvalues unavailable") end
end
log("===== END V15 =====")
