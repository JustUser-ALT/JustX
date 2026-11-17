-- Native Move Selection Diagnostic V26 (full mode event and action binding flow, read-only)
local RS=game:GetService("ReplicatedStorage")
local function log(s) print("[MoveState] "..tostring(s)) end
local function getLines(obj)
 if type(decompile)~="function" then return {} end
 local ok,s=pcall(decompile,obj)
 if not ok or type(s)~="string" then return {} end
 local t={}
 for line in string.gmatch(s,"([^\n]+)") do t[#t+1]=line end
 return t
end
local function dumpRange(label,obj,first,last)
 log("===== "..label.." =====")
 local t=getLines(obj)
 log("SOURCE LINES="..#t)
 if #t==0 then return end
 for i=math.max(1,first),math.min(#t,last) do log("L"..i.." "..string.sub(t[i],1,260)) end
end
local bm=RS:WaitForChild("BuildMode")
local bc=bm:FindFirstChild("BuildModeClient")
local modes=bm:FindFirstChild("Modes")
local move=modes and modes:FindFirstChild("Move")
local t=getLines(bc)
dumpRange("BUILD MODE CLIENT EVENT HANDLER",bc,285,330)
dumpRange("BUILD MODE CLIENT BIND ACTIONS",bc,600,700)
dumpRange("MOVE MODE COMPLETE",move,1,65)
log("===== END V26 =====")
