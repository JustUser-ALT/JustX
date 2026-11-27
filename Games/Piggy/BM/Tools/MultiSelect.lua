-- Shared MultiSelect controller for Piggy Build Mode: Move / Resize / Rotate.
local Env=(getgenv and getgenv()) or _G
if type(Env.JustXPiggyMultiSelectRegister)=="function" then return Env.JustXPiggyMultiSelectRegister end
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Player=Players.LocalPlayer
local PlayerGui=Player:WaitForChild("PlayerGui")
local BuildGui=PlayerGui:WaitForChild("BuildModeGui")
local BuildModel=workspace:WaitForChild("BuildModel")
local BF=RS:WaitForChild("BuildMode")
local BuildingMode=require(BF:WaitForChild("BuildingMode"))
local Changed=BF:WaitForChild("Events"):WaitForChild("BuildingModeChanged")
local Placement=require(BF:WaitForChild("PlacementLogic")).new()
local Box=require(RS.Packages.CustomAdornments.BoxSelectionAdornment)
local MoveMode=require(BF.Modes.Move)
local ResizeMode=require(BF.Modes.Resize)
local ClientState
for n=1,100 do
 for _,v in ipairs(getgc(true)) do
  if type(v)=="table" and rawget(v,"ScreenGui")==BuildGui and rawget(v,"Toolbar") and type(rawget(v,"PlaceBlockAction"))=="function" then ClientState=v break end
 end
 if ClientState then break end
 task.wait(.1)
end
assert(ClientState,"[MultiSelect] BuildModeClient missing")
local MH,RH=ClientState.MoveHandles,ClientState.ResizeHandles
assert(MH and RH,"[MultiSelect] Native handles missing")
local NativeMoveUpdate,NativeResizeUpdate=MoveMode.Update,ResizeMode.Update
local MoveSet,ResizeSet=MH.SetAdornee,RH.SetAdornee
local MoveRaw,ResizeRaw=rawget(MH,"SetAdornee"),rawget(RH,"SetAdornee")
local OriginalMoveAdornee,OriginalResizeAdornee=MH._Adornee,RH._Adornee
local Selection,Outlines,Connections,Registered={},{},{},{}
local Enabled,Cleaned,Busy=false,false,false
local MoveSession,ResizeActive,ResizeDriver=nil,false,nil
local ResizeObjects={}
local ActiveModeName
local RotateMode,RotateOriginalUpdate,PreviousPivot=nil,nil,nil
local OriginalAction,WrappedAction
local Toggle
local function Mode(mode)
 mode=mode or BuildingMode:Get()
 if type(mode)=="table" and mode.Name then return mode.Name end
 return tostring(mode):match("([^%.]+)$") or tostring(mode)
end
local function Is(name) return Mode()==name end
local function Valid(b) return typeof(b)=="Instance" and b:IsA("Model") and b.Parent==BuildModel and b.PrimaryPart~=nil end
local function Index(b) for i,v in ipairs(Selection) do if v==b then return i end end end
local function Driver() local b=Selection[#Selection] if Valid(b) then return b end end
local function Hover()
 local ok,r=pcall(function() return Placement:Raycast() end)
 if ok and r and r.Instance and Valid(r.Instance.Parent) then return r.Instance.Parent end
end
local function ButtonColor()
 if Toggle then Toggle.BackgroundColor3=Enabled and Color3.fromRGB(97,255,115) or Color3.fromRGB(255,142,142) end
end
local Gui=Instance.new("ScreenGui")
Gui.Name="JustXPiggyMultiSelect" Gui.ResetOnSpawn=false Gui.IgnoreGuiInset=true Gui.DisplayOrder=10001 Gui.Enabled=false
Toggle=Instance.new("ImageButton")
Toggle.Name="MultiSelectButton" Toggle.Size=UDim2.fromOffset(56.316,56.316)
Toggle.Position=UDim2.new(0,72,1,0) Toggle.AnchorPoint=Vector2.new(0,1)
Toggle.BackgroundColor3=Color3.fromRGB(255,142,142) Toggle.BorderSizePixel=0 Toggle.Image=""
Toggle.AutoButtonColor=true Toggle.Active=true Toggle.Selectable=true Toggle.ZIndex=1 Toggle.Parent=Gui
local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,10) corner.Parent=Toggle
local aspect=Instance.new("UIAspectRatioConstraint") aspect.AspectRatio=1 aspect.DominantAxis=Enum.DominantAxis.Width aspect.Parent=Toggle
local shadow=Instance.new("ImageLabel") shadow.Name="DropShadow" shadow.Size=UDim2.new(1,10,1,10)
shadow.Position=UDim2.new(.5,1,.5,1) shadow.AnchorPoint=Vector2.new(.5,.5) shadow.BackgroundTransparency=1
shadow.Image="rbxassetid://6865151684" shadow.ImageColor3=Color3.new(0,0,0) shadow.ImageTransparency=.2
shadow.ScaleType=Enum.ScaleType.Slice shadow.ZIndex=0 shadow.Parent=Toggle
local stroke=Instance.new("UIStroke") stroke.Name="TutStroke" stroke.Color=Color3.fromRGB(101,255,98)
stroke.Thickness=1 stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border stroke.Enabled=false stroke.Parent=Toggle
local label=Instance.new("TextLabel") label.Name="TextLabel" label.Size=UDim2.fromScale(1,1)
label.BackgroundTransparency=1 label.Text="MULTI" label.TextColor3=Color3.new(0,0,0)
label.TextSize=14 label.TextScaled=true label.Font=Enum.Font.GothamBold label.ZIndex=2 label.Parent=Toggle
Gui.Parent=PlayerGui
local function OutlineColor()
 if Is("Resize") then return Color3.fromRGB(255,127,0) end
 if Is("Rotate") then return Color3.fromRGB(170,85,255) end
 return Color3.fromRGB(0,0,255)
end
local function AddOutline(b)
 if not Valid(b) or Outlines[b] then return end
 local o
 local ok,err=pcall(function() o=Box.new() o:SetParent(BuildGui.Frame.Adornment) o:SetColor(OutlineColor()) o:SetThickness(.1) o:SetAdornee(b) end)
 if ok then Outlines[b]=o elseif o then pcall(function() o:Destroy() end) warn("[MultiSelect] Outline:",err) end
end
local function RemoveOutline(b)
 local o=Outlines[b] Outlines[b]=nil
 if o then pcall(function() o:SetAdornee(nil) o:Destroy() end) end
end
local function RefreshOutlines()
 for i=#Selection,1,-1 do
  local b=Selection[i]
  if not Valid(b) then table.remove(Selection,i) RemoveOutline(b)
  else
   if not Outlines[b] then AddOutline(b) end
   local o=Outlines[b] if o then pcall(function() o:SetAdornee(nil) o:SetAdornee(b) end) end
  end
 end
end
local function Proxy(name)
 local m=Instance.new("Model") m.Name=name
 local p=Instance.new("Part") p.Name="GroupBounds" p.Anchored=true p.Transparency=1 p.Size=Vector3.one
 p.CanCollide=false p.CanTouch=false p.CanQuery=false p.CastShadow=false p.Locked=true p.Parent=m
 m.PrimaryPart=p m.Parent=workspace return m,p
end
local MP,MPP=Proxy("JustXMultiMoveBounds")
local RP,RPP=Proxy("JustXMultiResizeBounds")
local function Bounds(driver)
 if not Valid(driver) then return end
 local pivot=driver:GetPivot()
 local mn=Vector3.new(math.huge,math.huge,math.huge)
 local mx=Vector3.new(-math.huge,-math.huge,-math.huge)
 local found=false
 for _,b in ipairs(Selection) do
  if Valid(b) then
   local cf,size=b:GetBoundingBox() local h=size*.5
   for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
    local q=pivot:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(h.X*x,h.Y*y,h.Z*z)))
    mn=Vector3.new(math.min(mn.X,q.X),math.min(mn.Y,q.Y),math.min(mn.Z,q.Z))
    mx=Vector3.new(math.max(mx.X,q.X),math.max(mx.Y,q.Y),math.max(mx.Z,q.Z)) found=true
   end end end
  end
 end
 if not found then return end
 local center=(mn+mx)*.5 local size=mx-mn
 return CFrame.new(pivot:PointToWorldSpace(center))*pivot.Rotation,size
end
local function UpdateProxy(m,p)
 local cf,size=Bounds(Driver()) if not cf then return false end
 p.Size=Vector3.new(math.max(size.X,.1),math.max(size.Y,.1),math.max(size.Z,.1)) m:PivotTo(cf) return true
end
local function Handles()
 ClientState.SelectedBlock=nil
 if Is("Move") then
  if #Selection>1 and UpdateProxy(MP,MPP) then pcall(MoveSet,MH,MP)
  elseif #Selection==1 then pcall(MoveSet,MH,Selection[1]) else pcall(MoveSet,MH,nil) end
 elseif Is("Resize") then
  if #Selection>1 and UpdateProxy(RP,RPP) then pcall(ResizeSet,RH,RP)
  elseif #Selection==1 then pcall(ResizeSet,RH,Selection[1]) else pcall(ResizeSet,RH,nil) end
 elseif Is("Rotate") then
  Env.RotateToolPivotOverride= function(model)
   if not Enabled or not Is("Rotate") or #Selection<2 or model~=Driver() then return end
   return Bounds(model)
  end
  if RotateMode and RotateMode.Active then ClientState.SelectedBlock=Driver() end
 end
end
local function CommitMove()
 local s=MoveSession MoveSession=nil if not s then return end
 local remote=RS:FindFirstChild("Functions") and RS.Functions:FindFirstChild("CommitMove")
 if not remote or Busy then return end
 Busy=true task.spawn(function()
  for b in pairs(s.starts) do if b~=s.driver and Valid(b) then pcall(function() remote:InvokeServer(b,b:GetPivot()) end) end end
  Busy=false
 end)
end
local function CommitResize()
 if not ResizeActive then return end
 ResizeActive=false local driver=ResizeDriver ResizeDriver=nil
 if Busy then return end Busy=true
 local blocks={}
 for _,b in ipairs(Selection) do if b~=driver and Valid(b) then table.insert(blocks,b) end end
 task.spawn(function()
  local remote=RS:FindFirstChild("Functions") and RS.Functions:FindFirstChild("CommitResize")
  if remote then for _,b in ipairs(blocks) do if Valid(b) then
   local parts={} for _,v in ipairs(b:GetDescendants()) do if v:IsA("BasePart") and v.Name~="MouseFilterPart" then table.insert(parts,v) end end
   if #parts==1 then local p=parts[1] pcall(function() remote:InvokeServer(b,{p,p.CFrame,p.Size}) end)
   else warn("[MultiSelect] Resize commit skipped: additional blocks need exactly one real BasePart") end
  end end end
  task.wait() RefreshOutlines() Busy=false
 end)
end
local function CommitRotate()
 local driver=Driver() local remote=RS:FindFirstChild("Functions") and RS.Functions:FindFirstChild("CommitMove")
 if not driver or not remote or Busy then return end
 local list={} for _,b in ipairs(Selection) do if b~=driver and Valid(b) then table.insert(list,b) end end
 if #list==0 then return end
 Busy=true task.spawn(function() for _,b in ipairs(list) do pcall(function() remote:InvokeServer(b,b:GetPivot()) end) end Busy=false end)
end
local function CommitCurrent()
 if Is("Move") then
  local s=MoveSession
  if s and Valid(s.driver) then local delta=s.driver:GetPivot()*s.driverStart:Inverse() for b,start in pairs(s.starts) do if b~=s.driver and Valid(b) then pcall(function() b:PivotTo(delta*start) end) end end end
  CommitMove()
 elseif Is("Resize") then CommitResize()
 elseif Is("Rotate") then CommitRotate() end
end
local function Clear()
 if RotateMode then RotateMode._MultiLastPivot=nil RotateMode._MultiChanged=nil end
 local keys={} for b in pairs(Outlines) do table.insert(keys,b) end for _,b in ipairs(keys) do RemoveOutline(b) end
 table.clear(Selection) ClientState.SelectedBlock=nil pcall(MoveSet,MH,nil) pcall(ResizeSet,RH,nil)
 MoveSession=nil ResizeActive=false ResizeDriver=nil table.clear(ResizeObjects)
 MPP.Size=Vector3.one RPP.Size=Vector3.one MP:PivotTo(CFrame.new(0,-10000,0)) RP:PivotTo(CFrame.new(0,-10000,0))
 if RotateMode and RotateMode.Outline then pcall(function() RotateMode.Outline:SetAdornee(nil) end) end
 Env.RotateToolPivotOverride=PreviousPivot
 ButtonColor()
end
local function Reset()
 CommitCurrent() Enabled=false Clear() ButtonColor()
end
local function SelectBlock(b)
 if RotateMode then RotateMode._MultiLastPivot=nil end
 local i=Index(b)
 if i then table.remove(Selection,i) RemoveOutline(b) else table.insert(Selection,b) AddOutline(b) end
 Handles() ButtonColor()
end
local function Action(self,...)
 if Cleaned or not Enabled then return OriginalAction(self,...) end
 local mode=Mode()
 if mode~="Move" and mode~="Resize" and mode~="Rotate" then return OriginalAction(self,...) end
 ClientState.SelectedBlock=nil
 local b=Hover()
 if b then SelectBlock(b) else CommitCurrent() Clear() end
 return Enum.ContextActionResult.Sink
end
local function InstallAction()
 local current=ClientState.PlaceBlockAction
 if current~=WrappedAction then OriginalAction=current WrappedAction=Action ClientState.PlaceBlockAction=WrappedAction end
end
local function MoveUpdate(self,...)
 if not Enabled or not Is("Move") or #Selection==0 then return NativeMoveUpdate(self,...) end
 local target=#Selection>1 and MP or Selection[1]
 rawset(MH,"SetAdornee",function() end)
 local r=table.pack(pcall(NativeMoveUpdate,self,...))
 rawset(MH,"SetAdornee",MoveRaw)
 if not r[1] then error(r[2],0) end
 pcall(MoveSet,MH,target) return table.unpack(r,2,r.n)
end
local function ResizeUpdate(self,...)
 if not Enabled or not Is("Resize") or #Selection==0 then return NativeResizeUpdate(self,...) end
 local target=#Selection>1 and RP or Selection[1]
 rawset(RH,"SetAdornee",function() end)
 local r=table.pack(pcall(NativeResizeUpdate,self,...))
 rawset(RH,"SetAdornee",ResizeRaw)
 if not r[1] then error(r[2],0) end
 pcall(ResizeSet,RH,target) return table.unpack(r,2,r.n)
end
MoveMode.Update=MoveUpdate ResizeMode.Update=ResizeUpdate
local function BeginMove()
 if not Enabled or not Is("Move") or #Selection<2 then MoveSession=nil return end
 local d=ClientState.SelectedBlock if not Valid(d) or not Index(d) then d=Driver() end
 if not Valid(d) then return end
 ClientState.SelectedBlock=d
 local starts={} for _,b in ipairs(Selection) do if Valid(b) then starts[b]=b:GetPivot() end end
 MoveSession={driver=d,driverStart=d:GetPivot(),starts=starts}
end
local function ApplyMove()
 local s=MoveSession if not s or not Valid(s.driver) then return end
 local delta=s.driver:GetPivot()*s.driverStart:Inverse()
 for b,start in pairs(s.starts) do if b~=s.driver and Valid(b) then pcall(function() b:PivotTo(delta*start) end) end end
 UpdateProxy(MP,MPP)
end
local ResizeModule
local ok,conns=pcall(getconnections,RH.MouseButton1Down)
if ok and conns then for _,c in ipairs(conns) do
 local fn=c.Function
 if type(fn)=="function" then for _,v in pairs(debug.getupvalues(fn)) do
  if type(v)=="table" and type(rawget(v,"new"))=="function" and type(rawget(v,"Drag"))=="function" and type(rawget(v,"__index"))=="table" then ResizeModule=v break end
 end end
 if ResizeModule then break end
end end
local ResizeNew,ResizeDrag,ResizeIndex
if ResizeModule then
 ResizeIndex=ResizeModule.__index ResizeNew=ResizeModule.new ResizeDrag=ResizeIndex.Drag
 local function Parts(b) local t={} for _,v in ipairs(b:GetChildren()) do if v:IsA("BasePart") then table.insert(t,v) end end return t end
 ResizeModule.new=function(parts,dir,base,params)
  local native=ResizeNew(parts,dir,base,params) table.clear(ResizeObjects)
  if Enabled and Is("Resize") and #Selection>1 then
   local d=Driver()
   if Valid(d) then local world=d.PrimaryPart.CFrame:VectorToWorldSpace(dir)
    for _,b in ipairs(Selection) do if b~=d and Valid(b) then
     local bp=b.PrimaryPart local localDir=bp.CFrame:VectorToObjectSpace(world)
     local good,obj=pcall(ResizeNew,Parts(b),localDir,bp,params) if good and obj then table.insert(ResizeObjects,obj) end
    end end
   end
  end
  return native
 end
 ResizeIndex.Drag=function(self,delta,...)
  local result=table.pack(ResizeDrag(self,delta,...))
  if Enabled and Is("Resize") and #Selection>1 then for _,obj in ipairs(ResizeObjects) do pcall(ResizeDrag,obj,delta) end end
  return table.unpack(result,1,result.n)
 end
end
local function BeginResize()
 if not Enabled or not Is("Resize") or #Selection<2 then ResizeActive=false return end
 ResizeActive=true ResizeDriver=Driver() ClientState.SelectedBlock=ResizeDriver
end
local function AttachRotate()
 local mode=Env.RotateToolMode
 if type(mode)~="table" or mode==RotateMode then return end
 RotateMode=mode PreviousPivot=Env.RotateToolPivotOverride
 RotateOriginalUpdate=mode.Update
 mode.Update=function(self,dt,state)
  if not Enabled or not Is("Rotate") then return RotateOriginalUpdate(self,dt,state) end
  RefreshOutlines() local d=Driver() state=state or ClientState
  if not d then state.SelectedBlock=nil return RotateOriginalUpdate(self,dt,state) end
  state.SelectedBlock=d
  local r=table.pack(pcall(RotateOriginalUpdate,self,dt,state))
  local current=d:GetPivot()
  if not mode._MultiLastPivot then mode._MultiLastPivot=current
  else
   local delta=current*mode._MultiLastPivot:Inverse()
   local changed=(current.Position-mode._MultiLastPivot.Position).Magnitude>1e-5 or current.LookVector:Dot(mode._MultiLastPivot.LookVector)<.999999
   if changed then
    for _,b in ipairs(Selection) do if b~=d and Valid(b) then pcall(function() b:PivotTo(delta*b:GetPivot()) end) end end
    mode._MultiChanged=true
   end
   mode._MultiLastPivot=current
  end
  if not r[1] then error(r[2],0) end return table.unpack(r,2,r.n)
 end
end
local function CommitRotateRelease()
 if RotateMode and RotateMode._MultiChanged then RotateMode._MultiChanged=false CommitRotate() RefreshOutlines() end
end
table.insert(Connections,MH.MouseButton1Down:Connect(BeginMove))
table.insert(Connections,MH.MouseDrag:Connect(function() if MoveSession then ApplyMove() end end))
table.insert(Connections,MH.MouseButton1Up:Connect(function()
 if MoveSession then ApplyMove() task.defer(function() task.wait() CommitMove() ClientState.SelectedBlock=nil end) end
end))
table.insert(Connections,RH.MouseButton1Down:Connect(BeginResize))
table.insert(Connections,RH.MouseButton1Up:Connect(function()
 if ResizeActive then task.defer(function() task.wait() CommitResize() table.clear(ResizeObjects) ClientState.SelectedBlock=nil end) end
end))
table.insert(Connections,Toggle.Activated:Connect(function()
 if not Registered[Mode()] then return end
 if Enabled then Reset() else Enabled=true table.clear(Selection) ClientState.SelectedBlock=nil ButtonColor() Handles() end
end))
table.insert(Connections,Changed.Event:Connect(function(mode)
 task.defer(function()
  local name=Mode(mode)
  Gui.Enabled=Registered.Move or Registered.Resize or Registered.Rotate
  Toggle.Visible=Gui.Enabled and Registered[name]==true
  if Enabled and ActiveModeName and name~=ActiveModeName then Enabled=false Clear() end
  ActiveModeName=name
 end)
end))
table.insert(Connections,UIS.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 or input.KeyCode==Enum.KeyCode.ButtonR2 then
  task.defer(function() task.wait() if Is("Rotate") then CommitRotateRelease() end end)
 end
end))
table.insert(Connections,RunService.RenderStepped:Connect(function()
 if Cleaned then return end
 AttachRotate()
 if Enabled then
  RefreshOutlines()
  if Is("Move") then if MoveSession then ApplyMove() end if not MoveSession then ClientState.SelectedBlock=nil end UpdateProxy(MP,MPP)
  elseif Is("Resize") then if not ResizeActive then ClientState.SelectedBlock=nil end UpdateProxy(RP,RPP) if ResizeActive then RefreshOutlines() end
  elseif Is("Rotate") then Env.RotateToolPivotOverride=function(model) if Enabled and Is("Rotate") and #Selection>1 and model==Driver() then return Bounds(model) end end end
 end
end))
local function Cleanup()
 if Cleaned then return end Cleaned=true CommitCurrent()
 for _,c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
 if ClientState.PlaceBlockAction==WrappedAction then ClientState.PlaceBlockAction=OriginalAction end
 if MoveMode.Update==MoveUpdate then MoveMode.Update=NativeMoveUpdate end
 if ResizeMode.Update==ResizeUpdate then ResizeMode.Update=NativeResizeUpdate end
 if ResizeModule and ResizeNew and ResizeModule.new~=ResizeNew then ResizeModule.new=ResizeNew end
 if ResizeIndex and ResizeDrag and ResizeIndex.Drag~=ResizeDrag then ResizeIndex.Drag=ResizeDrag end
 if RotateMode and RotateOriginalUpdate then RotateMode.Update=RotateOriginalUpdate end
 Env.RotateToolPivotOverride=PreviousPivot
 local keys={} for b in pairs(Outlines) do table.insert(keys,b) end for _,b in ipairs(keys) do RemoveOutline(b) end
 table.clear(Selection) ClientState.SelectedBlock=nil pcall(MoveSet,MH,nil) pcall(ResizeSet,RH,nil) pcall(function() Gui:Destroy() MP:Destroy() RP:Destroy() end)
 pcall(MoveSet,MH,OriginalMoveAdornee and OriginalMoveAdornee.Parent and OriginalMoveAdornee or nil)
 pcall(ResizeSet,RH,OriginalResizeAdornee and OriginalResizeAdornee.Parent and OriginalResizeAdornee or nil)
 Env.JustXPiggyMultiSelectRegister=nil Env.JustXPiggyMultiSelectUnregister=nil Env.JustXPiggyMultiSelectSetBaseAction=nil Env.JustXPiggyMultiSelectGetBaseAction=nil Env.JustXPiggyMultiSelectRebindAction=nil Env.MultiSelectCleanup=nil
end
local function Register(name)
 if name~="Move" and name~="Resize" and name~="Rotate" then return end
 Registered[name]=true InstallAction()
 ActiveModeName=Mode()
 if name=="Rotate" then AttachRotate() end
 Gui.Enabled=true Toggle.Visible=Registered[Mode()]==true
 return true
end
local function Unregister(name)
 Registered[name]=nil
 if name=="Rotate" and RotateMode then
  if RotateOriginalUpdate then RotateMode.Update=RotateOriginalUpdate end
  Env.RotateToolPivotOverride=PreviousPivot
  RotateMode=nil
  RotateOriginalUpdate=nil
  PreviousPivot=nil
 end
 if not Registered.Move and not Registered.Resize and not Registered.Rotate then Cleanup() end
end
Env.JustXPiggyMultiSelectRegister=Register
Env.JustXPiggyMultiSelectUnregister=Unregister
Env.JustXPiggyMultiSelectGetBaseAction=function() return OriginalAction end
Env.JustXPiggyMultiSelectSetBaseAction=function(action)
 if type(action)=="function" then
  OriginalAction=action
  if ClientState.PlaceBlockAction~=WrappedAction then ClientState.PlaceBlockAction=WrappedAction end
 end
end
Env.JustXPiggyMultiSelectRebindAction=InstallAction
Env.MultiSelectCleanup=Cleanup
InstallAction()
ButtonColor()
return Register
