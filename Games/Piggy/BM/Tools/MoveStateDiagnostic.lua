-- Native Move Selection Diagnostic v14 (read-only)
local RS = game:GetService("ReplicatedStorage")
local root = RS:WaitForChild("BuildMode")
local count, LIMIT = 0, 100
local function log(s)
    if count >= LIMIT then return end
    count = count + 1
    print("[MoveState] " .. tostring(s))
end
local function raw(t,k)
    if type(t) ~= "table" then return nil end
    local ok,v = pcall(rawget,t,k)
    return ok and v or nil
end
local function describe(v)
    if typeof(v) == "Instance" then
        local ok,n = pcall(function() return v:GetFullName() end)
        return (ok and n or v.Name) .. " <" .. v.ClassName .. ">"
    end
    return type(v)
end
local function dumpTable(label,t,depth)
    if type(t) ~= "table" then return end
    local n = 0
    for k,v in pairs(t) do
        n = n + 1
        if n > 24 then log(label .. " ...more keys"); break end
        local key = tostring(k)
        if #key > 45 then key = string.sub(key,1,45) end
        log(label .. "[" .. key .. "]=" .. describe(v))
        if depth > 0 and type(v) == "table" then
            local hits = {}
            for _, wanted in ipairs({"SelectedBlock","MoveHandles","BoxSelection","Toolbar","BuildModeClient","BuildingModeToolbar","Placement","ClientState"}) do
                local x = raw(v,wanted)
                if x ~= nil then hits[#hits+1] = wanted .. "=" .. describe(x) end
            end
            if #hits > 0 then log(label .. "[" .. key .. "] MATCH " .. table.concat(hits," ; ")) end
        end
    end
end
local function inspectFunction(label,fn)
    if type(fn) ~= "function" then return end
    if not debug or type(debug.getupvalues) ~= "function" then
        log(label .. " getupvalues unavailable"); return
    end
    local ok,ups = pcall(debug.getupvalues,fn)
    if not ok or type(ups) ~= "table" then log(label .. " upvalues failed"); return end
    for i,v in pairs(ups) do
        log(label .. " U" .. tostring(i) .. "=" .. describe(v))
        if type(v) == "table" then dumpTable(label .. " U" .. tostring(i),v,1) end
    end
    if debug.getconstants then
        local cok,cs = pcall(debug.getconstants,fn)
        if cok and type(cs) == "table" then
            local n=0
            for i,c in pairs(cs) do
                if type(c)=="string" and (string.find(c,"Selected") or string.find(c,"Toolbar") or string.find(c,"Move") or string.find(c,"Mount") or string.find(c,"BuildMode")) then
                    log(label .. " CONST[" .. tostring(i) .. "]=" .. c)
                    n=n+1
                    if n>=18 then break end
                end
            end
        else
            log(label .. " constants unavailable")
        end
    end
end
log("===== TARGETED CONSTRUCTOR DIAGNOSTIC V14 =====")
local ok,client = pcall(require,root:WaitForChild("BuildModeClient"))
log("BuildModeClient require=" .. tostring(ok) .. " result=" .. describe(client))
if ok and type(client)=="table" then
    for _,name in ipairs({"new","Mount","BindBuildActions","PlaceBlockAction","Destroy"}) do
        local fn=raw(client,name)
        log("BuildModeClient." .. name .. "=" .. describe(fn))
        if name=="new" or name=="Mount" then inspectFunction("BuildModeClient." .. name,fn) end
    end
end
local gui=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("BuildModeGui")
log("GUI=" .. describe(gui))
local main=gui and gui:FindFirstChild("Main")
log("Main=" .. describe(main))
if main and main:IsA("LocalScript") then
    log("Main Disabled=" .. tostring(main.Disabled))
    if getsenv then
        local eok,env=pcall(getsenv,main)
        log("Main getsenv=" .. tostring(eok) .. " " .. describe(env))
        if eok and type(env)=="table" then dumpTable("Main ENV",env,0) end
    else
        log("getsenv unavailable")
    end
end
log("===== END V14 =====")
