--[[
╔══════════════════════════════════════════════════════════════╗
║               S C R I P T   H U B   v1.0                    ║
║         Universal (Keyless) + Main Game (Keyed)              ║
║                                                              ║
║  HOW TO USE:                                                 ║
║   1. Open your executor and attach to Roblox.                ║
║   2. Execute this file (Main.lua).                           ║
║   3. A GUI will appear — drag it anywhere you like.          ║
║   4. Universal tab: click Execute on any script.             ║
║   5. Main Game tab: enter your key first, then execute.      ║
║   6. Use the search bar to find scripts quickly.             ║
║                                                              ║
║  HOW TO ADD SCRIPTS:                                         ║
║   • Universal: edit Scripts/Universal.lua                    ║
║   • Main Game: edit Scripts/MainGame.lua                     ║
║   • Key list:  edit Modules/KeySystem.lua (VALID_KEYS table) ║
╚══════════════════════════════════════════════════════════════╝
]]

-- ════════════════════════════════════════════════════════════════
--  0.  LOAD MODULES  (inline — paste module code directly below
--      if your executor doesn't support require/loadfile)
-- ════════════════════════════════════════════════════════════════

-- ── KeySystem ────────────────────────────────────────────────────────────────
local KeySystem = (function()
    local M = {}

    -- ▸▸ ADD / REMOVE VALID KEYS HERE ◂◂
    M.VALID_KEYS = {
        "MYHUB-ALPHA-1234",
        "MYHUB-BETA-5678",
        "MYHUB-GAMMA-9999",
        "MYHUB-DELTA-ABCD",
    }

    M.KEY_FILE   = "ScriptHub_Key.txt"
    M.KEY_EXPIRY = nil        -- seconds until key expires, nil = never
    M.HWID_BIND  = true       -- prevent key sharing across machines

    local function getHWID()
        local ok, id = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
        if ok and id and id ~= "" then return id end
        local p = game:GetService("Players").LocalPlayer
        return tostring(p and p.UserId or 0).."_"..tostring(game.PlaceId)
    end

    local function readSaved()
        local ok, data = pcall(readfile, M.KEY_FILE)
        if ok and data then
            local k,h,t = data:match("^(.+)|(.+)|(%d+)$")
            if k then return k,h,tonumber(t) end
        end
        return nil,nil,nil
    end

    function M.Validate(input)
        if not input or input=="" then return false,"No key entered." end
        local key = input:gsub("%s+",""):upper()
        local valid = false
        for _,v in ipairs(M.VALID_KEYS) do
            if v:upper()==key then valid=true break end
        end
        if not valid then return false,"Invalid key — check your key and try again." end
        if M.HWID_BIND then
            local sk,sh,_ = readSaved()
            if sk and sk:upper()==key then
                if sh ~= getHWID() then
                    return false,"Key is bound to a different device."
                end
            end
        end
        return true,"Key accepted!"
    end

    function M.LoadSaved()
        local sk,sh,st = readSaved()
        if not sk then return nil end
        if M.KEY_EXPIRY and st and os.time()-st > M.KEY_EXPIRY then
            pcall(delfile,M.KEY_FILE) return nil
        end
        if M.HWID_BIND and sh and sh~=getHWID() then return nil end
        return sk
    end

    function M.Save(key)
        local hwid = getHWID()
        pcall(writefile, M.KEY_FILE, key:upper().."|"..hwid.."|"..tostring(os.time()))
    end

    function M.Clear()
        pcall(delfile, M.KEY_FILE)
    end

    return M
end)()

-- ── Universal Scripts ─────────────────────────────────────────────────────────
local Universal = {}
Universal.Scripts = {
    {name="Infinite Jump",      description="Press Space in mid-air to jump again.",              category="Movement",
     code=[[
local UIS=game:GetService("UserInputService")
local lp=game:GetService("Players").LocalPlayer
UIS.JumpRequest:Connect(function()
    if not lp.Character then return end
    local hum=lp.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
print("[Hub] Infinite Jump ON")
]]},
    {name="WalkSpeed Changer",  description="Sets your WalkSpeed to 50 (edit the code to change).", category="Movement",
     code=[[
local speed=50
local lp=game:GetService("Players").LocalPlayer
local function s() local h=lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") if h then h.WalkSpeed=speed end end
s() lp.CharacterAdded:Connect(function(c) c:WaitForChild("Humanoid").WalkSpeed=speed end)
print("[Hub] WalkSpeed -> "..speed)
]]},
    {name="High Jump",          description="Sets JumpPower to 120 for very high jumps.",          category="Movement",
     code=[[
local p=120
local lp=game:GetService("Players").LocalPlayer
local function s() local h=lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") if h then h.JumpPower=p end end
s() lp.CharacterAdded:Connect(function(c) c:WaitForChild("Humanoid").JumpPower=p end)
print("[Hub] JumpPower -> "..p)
]]},
    {name="Fly Script",         description="Hold Q to fly — WASD to steer, Space/Ctrl for up/down.", category="Movement",
     code=[[
local UIS=game:GetService("UserInputService") local RS=game:GetService("RunService")
local lp=game:GetService("Players").LocalPlayer local cam=workspace.CurrentCamera
local flying=false local bv,bg
local function start()
    local r=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") if not r then return end
    bv=Instance.new("BodyVelocity",r) bv.MaxForce=Vector3.new(1e5,1e5,1e5) bv.Velocity=Vector3.new(0,0,0)
    bg=Instance.new("BodyGyro",r) bg.MaxTorque=Vector3.new(1e5,1e5,1e5) bg.P=1e4 flying=true print("[Hub] Fly ON")
end
local function stop() if bv then bv:Destroy() end if bg then bg:Destroy() end flying=false print("[Hub] Fly OFF") end
UIS.InputBegan:Connect(function(i,g) if g then return end if i.KeyCode==Enum.KeyCode.Q then start() end end)
UIS.InputEnded:Connect(function(i) if i.KeyCode==Enum.KeyCode.Q then stop() end end)
RS.RenderStepped:Connect(function()
    if not flying then return end
    local r=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") if not r or not bv then return end
    local sp=60
    if UIS:IsKeyDown(Enum.KeyCode.W) then bv.Velocity=cam.CFrame.LookVector*sp
    elseif UIS:IsKeyDown(Enum.KeyCode.S) then bv.Velocity=-cam.CFrame.LookVector*sp
    elseif UIS:IsKeyDown(Enum.KeyCode.A) then bv.Velocity=-cam.CFrame.RightVector*sp
    elseif UIS:IsKeyDown(Enum.KeyCode.D) then bv.Velocity=cam.CFrame.RightVector*sp
    elseif UIS:IsKeyDown(Enum.KeyCode.Space) then bv.Velocity=Vector3.new(0,sp,0)
    elseif UIS:IsKeyDown(Enum.KeyCode.LeftControl) then bv.Velocity=Vector3.new(0,-sp,0)
    else bv.Velocity=Vector3.new(0,0,0) end
    bg.CFrame=cam.CFrame
end)
]]},
    {name="Noclip",             description="Toggle noclip with N — walk through walls.",           category="Movement",
     code=[[
local UIS=game:GetService("UserInputService") local RS=game:GetService("RunService")
local lp=game:GetService("Players").LocalPlayer local nc=false
UIS.InputBegan:Connect(function(i,g) if g then return end if i.KeyCode==Enum.KeyCode.N then nc=not nc print("[Hub] Noclip "..(nc and "ON" or "OFF")) end end)
RS.Stepped:Connect(function() if nc and lp.Character then for _,p in ipairs(lp.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end end)
]]},
    {name="Player ESP",         description="Red highlights on all players.",                       category="Visual",
     code=[[
local Players=game:GetService("Players") local lp=Players.LocalPlayer local store={}
local function make(char) local h=Instance.new("Highlight") h.FillColor=Color3.fromRGB(255,50,50) h.OutlineColor=Color3.fromRGB(255,255,255) h.FillTransparency=0.5 h.Parent=char return h end
local function add(p) if p==lp then return end
    local function onChar(c) if store[p] then store[p]:Destroy() end store[p]=make(c) end
    if p.Character then onChar(p.Character) end
    p.CharacterAdded:Connect(onChar)
    p.CharacterRemoving:Connect(function() if store[p] then store[p]:Destroy() store[p]=nil end end)
end
for _,p in ipairs(Players:GetPlayers()) do add(p) end
Players.PlayerAdded:Connect(add)
Players.PlayerRemoving:Connect(function(p) if store[p] then store[p]:Destroy() store[p]=nil end end)
print("[Hub] Player ESP ON")
]]},
    {name="Fullbright",         description="Max brightness — see in the dark.",                   category="Visual",
     code=[[
local L=game:GetService("Lighting") L.Brightness=2 L.ClockTime=14 L.FogEnd=1e6 L.GlobalShadows=false L.Ambient=Color3.fromRGB(178,178,178) L.OutdoorAmbient=Color3.fromRGB(178,178,178) print("[Hub] Fullbright ON")
]]},
    {name="FOV Changer",        description="Sets camera FOV to 90.",                              category="Visual",
     code=[[workspace.CurrentCamera.FieldOfView=90 print("[Hub] FOV -> 90")]]},
    {name="Anti-AFK",           description="Prevents idle kick.",                                 category="Utility",
     code=[[
local VU=game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    VU:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
    task.wait(1)
    VU:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
end)
print("[Hub] Anti-AFK ON")
]]},
    {name="Rejoin",             description="Instantly rejoins this game.",                        category="Utility",
     code=[[game:GetService("TeleportService"):Teleport(game.PlaceId,game:GetService("Players").LocalPlayer)]]},
    {name="Copy Server Link",   description="Copies the join link for this server.",               category="Utility",
     code=[[
local link="roblox://experiences/start?placeId="..game.PlaceId.."&gameInstanceId="..game.JobId
setclipboard(link) print("[Hub] Copied: "..link)
]]},
    {name="Hide Character",     description="Makes your character invisible to yourself.",          category="Utility",
     code=[[
local lp=game:GetService("Players").LocalPlayer local char=lp.Character or lp.CharacterAdded:Wait()
for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") or p:IsA("Decal") then p.Transparency=1 end end
print("[Hub] Character hidden")
]]},
}

-- ── Main Game Scripts ─────────────────────────────────────────────────────────
local MainGame = {}
MainGame.GAME_NAME     = "Blox Fruits"
MainGame.GAME_PLACE_ID = 2753915549
MainGame.Scripts = {
    {name="Auto Farm (Quest)",  description="Farms quest monsters automatically.",   category="Farm",
     code=[[
local Players=game:GetService("Players") local RS=game:GetService("RunService")
local lp=Players.LocalPlayer local char=lp.Character or lp.CharacterAdded:Wait()
local hum=char:WaitForChild("Humanoid") local root=char:WaitForChild("HumanoidRootPart")
local farming=true
local function nearest()
    local n,d=nil,math.huge
    for _,o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Model") and o:FindFirstChild("Humanoid") then
            local h=o:FindFirstChild("Humanoid") local r=o:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health>0 and h~=hum then
                local dist=(root.Position-r.Position).Magnitude
                if dist<d then n,d=o,dist end
            end
        end
    end
    return n
end
print("[Hub] Auto Farm ON")
while farming and task.wait(0.15) do
    if hum.Health<=0 then task.wait(2) char=lp.Character or lp.CharacterAdded:Wait() hum=char:WaitForChild("Humanoid") root=char:WaitForChild("HumanoidRootPart") end
    local t=nearest()
    if t then
        local tr=t:FindFirstChild("HumanoidRootPart")
        if tr then
            root.CFrame=tr.CFrame+Vector3.new(0,3,4)
            local tool=char:FindFirstChildOfClass("Tool")
            if tool and tool:FindFirstChild("Handle") then
                firetouchinterest(tool.Handle,tr,0) task.wait(0.05) firetouchinterest(tool.Handle,tr,1)
            end
        end
    end
end
]]},
    {name="Auto Eat Fruit",     description="Automatically eats any Devil Fruit on the ground.", category="Farm",
     code=[[
local lp=game:GetService("Players").LocalPlayer local char=lp.Character or lp.CharacterAdded:Wait()
local root=char:WaitForChild("HumanoidRootPart")
local function eat(obj)
    if obj.Name:find("Fruit") then
        local r=obj:FindFirstChild("Handle") or obj:FindFirstChildOfClass("Part")
        if r then root.CFrame=r.CFrame+Vector3.new(0,2,0) firetouchinterest(root,r,0) task.wait(0.2) firetouchinterest(root,r,1) print("[Hub] Ate: "..obj.Name) end
    end
end
for _,o in ipairs(workspace:GetDescendants()) do eat(o) end
workspace.DescendantAdded:Connect(function(o) task.wait(0.5) eat(o) end)
print("[Hub] Auto Eat Fruit ON")
]]},
    {name="Fruit ESP",          description="Gold highlights on all Devil Fruits.",               category="ESP",
     code=[[
local function hl()
    for _,o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Model") and o.Name:find("Fruit") and not o:FindFirstChildOfClass("Highlight") then
            local h=Instance.new("Highlight") h.FillColor=Color3.fromRGB(255,215,0) h.OutlineColor=Color3.fromRGB(255,255,255) h.FillTransparency=0.3 h.Parent=o
        end
    end
end
hl() workspace.DescendantAdded:Connect(function() task.wait(0.2) hl() end) print("[Hub] Fruit ESP ON")
]]},
    {name="Boss ESP",           description="Red highlights on all boss NPCs.",                   category="ESP",
     code=[[
local tags={"Boss","King","Admiral","Warlord","Dragon","Elite"}
local function isBoss(m) for _,t in ipairs(tags) do if m.Name:find(t) then return true end end end
local function add(m)
    if m:IsA("Model") and isBoss(m) and m:FindFirstChildOfClass("Humanoid") and not m:FindFirstChildOfClass("Highlight") then
        local h=Instance.new("Highlight") h.FillColor=Color3.fromRGB(220,30,30) h.OutlineColor=Color3.fromRGB(255,255,255) h.FillTransparency=0.4 h.Parent=m
    end
end
for _,v in ipairs(workspace:GetDescendants()) do add(v) end
workspace.DescendantAdded:Connect(add) print("[Hub] Boss ESP ON")
]]},
    {name="TP Sea 1",           description="Teleports to Sea 1 spawn.",                         category="Teleport",
     code=[[
local r=game:GetService("Players").LocalPlayer.Character:WaitForChild("HumanoidRootPart")
r.CFrame=CFrame.new(-1270,40,1760) print("[Hub] Teleported to Sea 1")
]]},
    {name="Kill Aura (Sword)",  description="Hits enemies within 10 studs with your sword.",     category="Combat",
     code=[[
local lp=game:GetService("Players").LocalPlayer local RS=game:GetService("RunService")
local char=lp.Character or lp.CharacterAdded:Wait() local root=char:WaitForChild("HumanoidRootPart")
RS.Heartbeat:Connect(function()
    char=lp.Character if not char then return end
    root=char:FindFirstChild("HumanoidRootPart") local tool=char:FindFirstChildOfClass("Tool")
    if not tool or not root then return end
    for _,o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Model") and o~=char then
            local eh=o:FindFirstChildOfClass("Humanoid") local er=o:FindFirstChild("HumanoidRootPart")
            if eh and er and eh.Health>0 and (root.Position-er.Position).Magnitude<10 then
                local h=tool:FindFirstChild("Handle")
                if h then firetouchinterest(h,er,0) task.wait(0.05) firetouchinterest(h,er,1) end
            end
        end
    end
end)
print("[Hub] Kill Aura ON")
]]},
    {name="Auto Stats Melee",   description="Dumps all stat points into Melee.",                 category="Stats",
     code=[[
local lp=game:GetService("Players").LocalPlayer
local remote=game:GetService("ReplicatedStorage"):FindFirstChild("Stat",true) or game:GetService("ReplicatedStorage"):FindFirstChild("AddStat",true)
if remote then
    local data=lp:WaitForChild("Data",10)
    if data then
        local pts=data:FindFirstChild("StatPoints") or data:FindFirstChild("Points")
        if pts then for i=1,pts.Value do remote:FireServer("Melee") end print("[Hub] Added "..pts.Value.." -> Melee") end
    end
else print("[Hub] Stat remote not found") end
]]},
    {name="Auto Accept Trade",  description="Accepts all trade requests automatically.",          category="Misc",
     code=[[
local RS=game:GetService("ReplicatedStorage")
RS.DescendantAdded:Connect(function(o)
    if o.Name:find("Trade") then
        task.wait(0.5)
        local r=RS:FindFirstChild("AcceptTrade",true)
        if r then r:FireServer() end
    end
end)
print("[Hub] Auto Accept Trade ON")
]]},
}

-- ════════════════════════════════════════════════════════════════
--  1.  CLEANUP  — destroy any old hub if re-executed
-- ════════════════════════════════════════════════════════════════
local OLD = game:GetService("CoreGui"):FindFirstChild("ScriptHub_GUI")
if OLD then OLD:Destroy() end
local OLD2 = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui") and
             game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ScriptHub_GUI")
if OLD2 then OLD2:Destroy() end

-- ════════════════════════════════════════════════════════════════
--  2.  COLOUR PALETTE & SIZES
-- ════════════════════════════════════════════════════════════════
local C = {
    BG        = Color3.fromRGB(15,  15,  20),
    SIDEBAR   = Color3.fromRGB(20,  20,  28),
    CARD      = Color3.fromRGB(26,  26,  36),
    CARDH     = Color3.fromRGB(32,  32,  46),
    ACCENT    = Color3.fromRGB(99,  102, 241),  -- indigo
    ACCENT2   = Color3.fromRGB(139, 92,  246),  -- violet
    DANGER    = Color3.fromRGB(239, 68,  68),
    SUCCESS   = Color3.fromRGB(34,  197, 94),
    WARNING   = Color3.fromRGB(234, 179, 8),
    TEXT      = Color3.fromRGB(240, 240, 255),
    SUBTEXT   = Color3.fromRGB(160, 160, 190),
    INPUT_BG  = Color3.fromRGB(30,  30,  42),
    DIVIDER   = Color3.fromRGB(40,  40,  56),
    KEY_BADGE = Color3.fromRGB(234, 179, 8),
}
local FONT        = Enum.Font.GothamBold
local FONT_SEMI   = Enum.Font.GothamSemibold
local FONT_BODY   = Enum.Font.Gotham

-- ════════════════════════════════════════════════════════════════
--  3.  SCREEN GUI + DRAG LOGIC
-- ════════════════════════════════════════════════════════════════
local function tryParent()
    local ok, CoreGui = pcall(function() return game:GetService("CoreGui") end)
    if ok and CoreGui then return CoreGui end
    return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name              = "ScriptHub_GUI"
ScreenGui.ResetOnSpawn      = false
ScreenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder      = 99
ScreenGui.IgnoreGuiInset    = true
ScreenGui.Parent            = tryParent()

-- Root window
local WIN_W, WIN_H = 820, 520
local Window = Instance.new("Frame")
Window.Name              = "Window"
Window.Size              = UDim2.new(0, WIN_W, 0, WIN_H)
Window.Position          = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Window.BackgroundColor3  = C.BG
Window.BorderSizePixel   = 0
Window.ClipsDescendants  = true
Window.Parent            = ScreenGui
Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 12)

-- Drop shadow (decorative frame behind window)
local Shadow = Instance.new("Frame")
Shadow.Size             = UDim2.new(1, 20, 1, 20)
Shadow.Position         = UDim2.new(0, -10, 0, 6)
Shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Shadow.BackgroundTransparency = 0.55
Shadow.BorderSizePixel  = 0
Shadow.ZIndex           = 0
Shadow.Parent           = Window
Instance.new("UICorner", Shadow).CornerRadius = UDim.new(0, 16)

-- Drag logic
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
do
    local dragging, dragStart, startPos = false, nil, nil
    Window.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = Window.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                         input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Window.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
--  4.  SIDEBAR
-- ════════════════════════════════════════════════════════════════
local Sidebar = Instance.new("Frame")
Sidebar.Name            = "Sidebar"
Sidebar.Size            = UDim2.new(0, 180, 1, 0)
Sidebar.BackgroundColor3= C.SIDEBAR
Sidebar.BorderSizePixel = 0
Sidebar.Parent          = Window
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 12)

-- Right edge square filler (so right corners are flush with main content)
local SBFill = Instance.new("Frame")
SBFill.Size             = UDim2.new(0, 12, 1, 0)
SBFill.Position         = UDim2.new(1, -12, 0, 0)
SBFill.BackgroundColor3 = C.SIDEBAR
SBFill.BorderSizePixel  = 0
SBFill.Parent           = Sidebar

-- Hub logo / title area
local LogoArea = Instance.new("Frame")
LogoArea.Size            = UDim2.new(1, 0, 0, 70)
LogoArea.BackgroundTransparency = 1
LogoArea.Parent          = Sidebar

local LogoLabel = Instance.new("TextLabel")
LogoLabel.Size            = UDim2.new(1, -16, 0, 28)
LogoLabel.Position        = UDim2.new(0, 8, 0, 14)
LogoLabel.BackgroundTransparency = 1
LogoLabel.Text            = "SCRIPT HUB"
LogoLabel.TextColor3      = C.TEXT
LogoLabel.Font            = FONT
LogoLabel.TextSize        = 17
LogoLabel.TextXAlignment  = Enum.TextXAlignment.Left
LogoLabel.Parent          = LogoArea

local VersionLabel = Instance.new("TextLabel")
VersionLabel.Size           = UDim2.new(1, -16, 0, 16)
VersionLabel.Position       = UDim2.new(0, 8, 0, 44)
VersionLabel.BackgroundTransparency = 1
VersionLabel.Text           = "v1.0  •  Keyless + Keyed"
VersionLabel.TextColor3     = C.SUBTEXT
VersionLabel.Font           = FONT_BODY
VersionLabel.TextSize       = 11
VersionLabel.TextXAlignment = Enum.TextXAlignment.Left
VersionLabel.Parent         = LogoArea

-- Divider under logo
local LogoDivider = Instance.new("Frame")
LogoDivider.Size            = UDim2.new(1, -24, 0, 1)
LogoDivider.Position        = UDim2.new(0, 12, 0, 70)
LogoDivider.BackgroundColor3= C.DIVIDER
LogoDivider.BorderSizePixel = 0
LogoDivider.Parent          = Sidebar

-- Tab button builder
local NAV_TABS = {
    { id="universal", label="🌐  Universal",  color=C.ACCENT  },
    { id="maingame",  label="🔐  Main Game",  color=C.WARNING },
    { id="settings",  label="⚙️  Settings",   color=C.SUBTEXT },
}
local tabButtons = {}

for i, tab in ipairs(NAV_TABS) do
    local btn = Instance.new("TextButton")
    btn.Name              = "Tab_"..tab.id
    btn.Size              = UDim2.new(1, -16, 0, 40)
    btn.Position          = UDim2.new(0, 8, 0, 80 + (i-1)*48)
    btn.BackgroundColor3  = C.SIDEBAR
    btn.BorderSizePixel   = 0
    btn.Text              = tab.label
    btn.TextColor3        = C.SUBTEXT
    btn.Font              = FONT_SEMI
    btn.TextSize          = 13
    btn.TextXAlignment    = Enum.TextXAlignment.Left
    btn.AutoButtonColor   = false
    btn.Parent            = Sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    -- left indent for text
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.Parent = btn
    tabButtons[tab.id] = btn
end

-- Close button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size            = UDim2.new(1, -16, 0, 36)
CloseBtn.Position        = UDim2.new(0, 8, 1, -48)
CloseBtn.BackgroundColor3= Color3.fromRGB(35, 20, 20)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text            = "✕  Close"
CloseBtn.TextColor3      = C.DANGER
CloseBtn.Font            = FONT_SEMI
CloseBtn.TextSize        = 13
CloseBtn.TextXAlignment  = Enum.TextXAlignment.Left
CloseBtn.AutoButtonColor = false
CloseBtn.Parent          = Sidebar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)
local cpd = Instance.new("UIPadding") cpd.PaddingLeft = UDim.new(0, 12) cpd.Parent = CloseBtn
CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(Window, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size=UDim2.new(0,WIN_W,0,0)}):Play()
    task.wait(0.3) ScreenGui:Destroy()
end)

-- ════════════════════════════════════════════════════════════════
--  5.  CONTENT AREA
-- ════════════════════════════════════════════════════════════════
local Content = Instance.new("Frame")
Content.Name            = "Content"
Content.Size            = UDim2.new(1, -180, 1, 0)
Content.Position        = UDim2.new(0, 180, 0, 0)
Content.BackgroundTransparency = 1
Content.ClipsDescendants= true
Content.Parent          = Window

-- ── Notification toast ──────────────────────────────────────────
local Toast = Instance.new("Frame")
Toast.Name              = "Toast"
Toast.Size              = UDim2.new(1, -32, 0, 36)
Toast.Position          = UDim2.new(0, 16, 1, 10)
Toast.BackgroundColor3  = C.SUCCESS
Toast.BorderSizePixel   = 0
Toast.Parent            = Window
Instance.new("UICorner", Toast).CornerRadius = UDim.new(0, 8)
local ToastLabel = Instance.new("TextLabel")
ToastLabel.Size              = UDim2.new(1, -16, 1, 0)
ToastLabel.Position          = UDim2.new(0, 8, 0, 0)
ToastLabel.BackgroundTransparency = 1
ToastLabel.Text              = ""
ToastLabel.TextColor3        = Color3.fromRGB(255,255,255)
ToastLabel.Font              = FONT_SEMI
ToastLabel.TextSize          = 13
ToastLabel.TextXAlignment    = Enum.TextXAlignment.Left
ToastLabel.Parent            = Toast

local toastActive = false
local function showToast(msg, color, duration)
    if toastActive then return end
    toastActive = true
    Toast.BackgroundColor3 = color or C.SUCCESS
    ToastLabel.Text = msg
    TweenService:Create(Toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position=UDim2.new(0,16,1,-50)}):Play()
    task.wait(duration or 2.5)
    TweenService:Create(Toast, TweenInfo.new(0.25), {Position=UDim2.new(0,16,1,10)}):Play()
    task.wait(0.3)
    toastActive = false
end

-- ── Search bar (always visible in content area) ─────────────────
local SearchBar = Instance.new("Frame")
SearchBar.Size            = UDim2.new(1, -32, 0, 38)
SearchBar.Position        = UDim2.new(0, 16, 0, 12)
SearchBar.BackgroundColor3= C.INPUT_BG
SearchBar.BorderSizePixel = 0
SearchBar.Parent          = Content
Instance.new("UICorner", SearchBar).CornerRadius = UDim.new(0, 8)

local SearchIcon = Instance.new("TextLabel")
SearchIcon.Size             = UDim2.new(0, 32, 1, 0)
SearchIcon.BackgroundTransparency = 1
SearchIcon.Text             = "🔍"
SearchIcon.TextSize         = 14
SearchIcon.Font             = FONT_BODY
SearchIcon.Parent           = SearchBar

local SearchInput = Instance.new("TextBox")
SearchInput.Size            = UDim2.new(1, -44, 1, 0)
SearchInput.Position        = UDim2.new(0, 36, 0, 0)
SearchInput.BackgroundTransparency = 1
SearchInput.PlaceholderText = "Search scripts..."
SearchInput.PlaceholderColor3 = C.SUBTEXT
SearchInput.Text            = ""
SearchInput.TextColor3      = C.TEXT
SearchInput.Font            = FONT_BODY
SearchInput.TextSize        = 13
SearchInput.TextXAlignment  = Enum.TextXAlignment.Left
SearchInput.ClearTextOnFocus= false
SearchInput.Parent          = SearchBar

-- ── Page container ──────────────────────────────────────────────
local Pages = Instance.new("Frame")
Pages.Name              = "Pages"
Pages.Size              = UDim2.new(1, 0, 1, -62)
Pages.Position          = UDim2.new(0, 0, 0, 62)
Pages.BackgroundTransparency = 1
Pages.ClipsDescendants  = true
Pages.Parent            = Content

-- ════════════════════════════════════════════════════════════════
--  6.  HELPERS: SCROLL FRAME + SCRIPT CARD BUILDER
-- ════════════════════════════════════════════════════════════════
local function makeScrollFrame(parent)
    local sf = Instance.new("ScrollingFrame")
    sf.Size                   = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel        = 0
    sf.ScrollBarThickness     = 4
    sf.ScrollBarImageColor3   = C.ACCENT
    sf.CanvasSize             = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    sf.Parent                 = parent

    local layout = Instance.new("UIListLayout")
    layout.Padding            = UDim.new(0, 8)
    layout.SortOrder          = Enum.SortOrder.LayoutOrder
    layout.Parent             = sf

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, 16)
    pad.PaddingRight  = UDim.new(0, 16)
    pad.PaddingTop    = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent        = sf

    return sf, layout
end

local function makeScriptCard(script, parent, locked)
    local card = Instance.new("Frame")
    card.Name              = script.name
    card.Size              = UDim2.new(1, 0, 0, 72)
    card.BackgroundColor3  = C.CARD
    card.BorderSizePixel   = 0
    card.Parent            = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    -- Category badge
    local badge = Instance.new("TextLabel")
    badge.Size             = UDim2.new(0, 80, 0, 18)
    badge.Position         = UDim2.new(1, -92, 0, 10)
    badge.BackgroundColor3 = locked and Color3.fromRGB(40,30,10) or Color3.fromRGB(25,25,45)
    badge.BorderSizePixel  = 0
    badge.Text             = script.category
    badge.TextColor3       = locked and C.WARNING or C.ACCENT
    badge.Font             = FONT_SEMI
    badge.TextSize         = 10
    badge.Parent           = card
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 5)

    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size            = UDim2.new(1, -110, 0, 22)
    nameLabel.Position        = UDim2.new(0, 14, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text            = script.name
    nameLabel.TextColor3      = C.TEXT
    nameLabel.Font            = FONT
    nameLabel.TextSize        = 14
    nameLabel.TextXAlignment  = Enum.TextXAlignment.Left
    nameLabel.Parent          = card

    -- Description
    local desc = Instance.new("TextLabel")
    desc.Size                 = UDim2.new(1, -110, 0, 16)
    desc.Position             = UDim2.new(0, 14, 0, 34)
    desc.BackgroundTransparency = 1
    desc.Text                 = script.description
    desc.TextColor3           = C.SUBTEXT
    desc.Font                 = FONT_BODY
    desc.TextSize             = 12
    desc.TextXAlignment       = Enum.TextXAlignment.Left
    desc.TextTruncate         = Enum.TextTruncate.AtEnd
    desc.Parent               = card

    -- Execute button
    local execBtn = Instance.new("TextButton")
    execBtn.Size              = UDim2.new(0, 90, 0, 28)
    execBtn.Position          = UDim2.new(0, 14, 1, -38)
    execBtn.BackgroundColor3  = locked and Color3.fromRGB(50,40,10) or C.ACCENT
    execBtn.BorderSizePixel   = 0
    execBtn.Text              = locked and "🔒 Locked" or "▶ Execute"
    execBtn.TextColor3        = locked and C.WARNING or Color3.fromRGB(255,255,255)
    execBtn.Font              = FONT_SEMI
    execBtn.TextSize          = 12
    execBtn.AutoButtonColor   = false
    execBtn.Parent            = card
    Instance.new("UICorner", execBtn).CornerRadius = UDim.new(0, 7)

    -- Hover effect
    card.MouseEnter:Connect(function() card.BackgroundColor3 = C.CARDH end)
    card.MouseLeave:Connect(function() card.BackgroundColor3 = C.CARD  end)

    execBtn.MouseEnter:Connect(function()
        if not locked then
            TweenService:Create(execBtn, TweenInfo.new(0.15), {BackgroundColor3=C.ACCENT2}):Play()
        end
    end)
    execBtn.MouseLeave:Connect(function()
        if not locked then
            TweenService:Create(execBtn, TweenInfo.new(0.15), {BackgroundColor3=C.ACCENT}):Play()
        end
    end)

    return card, execBtn
end

-- ════════════════════════════════════════════════════════════════
--  7.  PAGE: UNIVERSAL (keyless)
-- ════════════════════════════════════════════════════════════════
local PageUniversal = Instance.new("Frame")
PageUniversal.Name              = "PageUniversal"
PageUniversal.Size              = UDim2.new(1, 0, 1, 0)
PageUniversal.BackgroundTransparency = 1
PageUniversal.Parent            = Pages

local uScroll, uLayout = makeScrollFrame(PageUniversal)

local uCards = {} -- {frame, execBtn, script} — for search filtering
for i, s in ipairs(Universal.Scripts) do
    local card, execBtn = makeScriptCard(s, uScroll, false)
    card.LayoutOrder = i
    table.insert(uCards, {frame=card, script=s})
    execBtn.MouseButton1Click:Connect(function()
        local ok, err = pcall(loadstring(s.code))
        task.spawn(function()
            if ok then
                showToast("✔  Executed: " .. s.name, C.SUCCESS)
            else
                showToast("✘  Error: " .. tostring(err):sub(1, 60), C.DANGER, 4)
            end
        end)
    end)
end

-- ════════════════════════════════════════════════════════════════
--  8.  PAGE: MAIN GAME (keyed)
-- ════════════════════════════════════════════════════════════════
local keyUnlocked = false
local PageMainGame = Instance.new("Frame")
PageMainGame.Name              = "PageMainGame"
PageMainGame.Size              = UDim2.new(1, 0, 1, 0)
PageMainGame.BackgroundTransparency = 1
PageMainGame.Visible           = false
PageMainGame.Parent            = Pages

-- ── Key gate overlay ────────────────────────────────────────────
local KeyGate = Instance.new("Frame")
KeyGate.Name            = "KeyGate"
KeyGate.Size            = UDim2.new(1, 0, 1, 0)
KeyGate.BackgroundColor3= C.BG
KeyGate.BorderSizePixel = 0
KeyGate.ZIndex          = 10
KeyGate.Parent          = PageMainGame
Instance.new("UICorner", KeyGate).CornerRadius = UDim.new(0, 12)

local KeyCard = Instance.new("Frame")
KeyCard.Size              = UDim2.new(0, 360, 0, 240)
KeyCard.Position          = UDim2.new(0.5, -180, 0.5, -120)
KeyCard.BackgroundColor3  = C.CARD
KeyCard.BorderSizePixel   = 0
KeyCard.ZIndex            = 11
KeyCard.Parent            = KeyGate
Instance.new("UICorner", KeyCard).CornerRadius = UDim.new(0, 12)

local KTitle = Instance.new("TextLabel")
KTitle.Size               = UDim2.new(1, -32, 0, 28)
KTitle.Position           = UDim2.new(0, 16, 0, 18)
KTitle.BackgroundTransparency = 1
KTitle.Text               = "🔐  Main Game — Key Required"
KTitle.TextColor3         = C.TEXT
KTitle.Font               = FONT
KTitle.TextSize           = 16
KTitle.TextXAlignment     = Enum.TextXAlignment.Left
KTitle.ZIndex             = 12
KTitle.Parent             = KeyCard

local KSub = Instance.new("TextLabel")
KSub.Size                 = UDim2.new(1, -32, 0, 18)
KSub.Position             = UDim2.new(0, 16, 0, 50)
KSub.BackgroundTransparency = 1
KSub.Text                 = "Enter your key to unlock "..MainGame.GAME_NAME.." scripts:"
KSub.TextColor3           = C.SUBTEXT
KSub.Font                 = FONT_BODY
KSub.TextSize             = 12
KSub.TextXAlignment       = Enum.TextXAlignment.Left
KSub.ZIndex               = 12
KSub.Parent               = KeyCard

local KInputFrame = Instance.new("Frame")
KInputFrame.Size          = UDim2.new(1, -32, 0, 40)
KInputFrame.Position      = UDim2.new(0, 16, 0, 80)
KInputFrame.BackgroundColor3 = C.INPUT_BG
KInputFrame.BorderSizePixel  = 0
KInputFrame.ZIndex        = 12
KInputFrame.Parent        = KeyCard
Instance.new("UICorner", KInputFrame).CornerRadius = UDim.new(0, 8)
local kPad = Instance.new("UIPadding") kPad.PaddingLeft = UDim.new(0,10) kPad.Parent = KInputFrame

local KInput = Instance.new("TextBox")
KInput.Size               = UDim2.new(1, -10, 1, 0)
KInput.BackgroundTransparency = 1
KInput.PlaceholderText    = "MYHUB-XXXX-XXXX"
KInput.PlaceholderColor3  = C.SUBTEXT
KInput.Text               = ""
KInput.TextColor3         = C.TEXT
KInput.Font               = FONT_BODY
KInput.TextSize           = 13
KInput.TextXAlignment     = Enum.TextXAlignment.Left
KInput.ZIndex             = 13
KInput.Parent             = KInputFrame

local KStatus = Instance.new("TextLabel")
KStatus.Size              = UDim2.new(1, -32, 0, 18)
KStatus.Position          = UDim2.new(0, 16, 0, 130)
KStatus.BackgroundTransparency = 1
KStatus.Text              = ""
KStatus.TextColor3        = C.SUBTEXT
KStatus.Font              = FONT_SEMI
KStatus.TextSize          = 12
KStatus.TextXAlignment    = Enum.TextXAlignment.Left
KStatus.ZIndex            = 12
KStatus.Parent            = KeyCard

local KSubmit = Instance.new("TextButton")
KSubmit.Size              = UDim2.new(1, -32, 0, 40)
KSubmit.Position          = UDim2.new(0, 16, 0, 158)
KSubmit.BackgroundColor3  = C.ACCENT
KSubmit.BorderSizePixel   = 0
KSubmit.Text              = "Unlock Scripts"
KSubmit.TextColor3        = Color3.fromRGB(255,255,255)
KSubmit.Font              = FONT
KSubmit.TextSize          = 14
KSubmit.AutoButtonColor   = false
KSubmit.ZIndex            = 12
KSubmit.Parent            = KeyCard
Instance.new("UICorner", KSubmit).CornerRadius = UDim.new(0, 8)
KSubmit.MouseEnter:Connect(function() TweenService:Create(KSubmit,TweenInfo.new(0.15),{BackgroundColor3=C.ACCENT2}):Play() end)
KSubmit.MouseLeave:Connect(function() TweenService:Create(KSubmit,TweenInfo.new(0.15),{BackgroundColor3=C.ACCENT}):Play() end)

-- ── Script scroll (hidden until unlocked) ───────────────────────
local mgScroll, mgLayout = makeScrollFrame(PageMainGame)
mgScroll.Visible = false

local mgCards = {}
for i, s in ipairs(MainGame.Scripts) do
    local card, execBtn = makeScriptCard(s, mgScroll, true)
    card.LayoutOrder = i
    table.insert(mgCards, {frame=card, script=s, execBtn=execBtn})
end

-- ── Key submit handler ───────────────────────────────────────────
local function attemptUnlock(keyText)
    KStatus.TextColor3 = C.SUBTEXT
    KStatus.Text       = "Checking…"
    task.wait(0.4) -- small UX delay so it feels like it's checking

    local ok, reason = KeySystem.Validate(keyText)
    if ok then
        KeySystem.Save(keyText)
        keyUnlocked  = true
        KStatus.Text = "✔ " .. reason

        TweenService:Create(KeyGate, TweenInfo.new(0.4, Enum.EasingStyle.Quad),
            {BackgroundTransparency=1}):Play()
        task.wait(0.1)
        TweenService:Create(KeyCard, TweenInfo.new(0.3), {BackgroundTransparency=1}):Play()
        task.wait(0.3)
        KeyGate.Visible    = false
        mgScroll.Visible   = true

        -- Re-enable all locked cards
        for _, entry in ipairs(mgCards) do
            entry.execBtn.BackgroundColor3 = C.ACCENT
            entry.execBtn.Text             = "▶ Execute"
            entry.execBtn.TextColor3       = Color3.fromRGB(255,255,255)
            entry.execBtn.MouseButton1Click:Connect(function()
                local s = entry.script
                local eok, err = pcall(loadstring(s.code))
                task.spawn(function()
                    if eok then
                        showToast("✔  Executed: " .. s.name, C.SUCCESS)
                    else
                        showToast("✘  Error: " .. tostring(err):sub(1,60), C.DANGER, 4)
                    end
                end)
            end)
        end
        showToast("🔓  " .. MainGame.GAME_NAME .. " scripts unlocked!", C.SUCCESS)
    else
        KStatus.TextColor3 = C.DANGER
        KStatus.Text       = "✘ " .. reason
        TweenService:Create(KInputFrame, TweenInfo.new(0.06, Enum.EasingStyle.Bounce), {Position=UDim2.new(0,20,0,80)}):Play()
        task.wait(0.06)
        TweenService:Create(KInputFrame, TweenInfo.new(0.06), {Position=UDim2.new(0,16,0,80)}):Play()
    end
end

KSubmit.MouseButton1Click:Connect(function() attemptUnlock(KInput.Text) end)
KInput.FocusLost:Connect(function(enter) if enter then attemptUnlock(KInput.Text) end end)

-- Auto-load saved key
task.spawn(function()
    local saved = KeySystem.LoadSaved()
    if saved then
        KInput.Text = saved
        task.wait(0.8) -- wait for GUI to appear
        attemptUnlock(saved)
    end
end)

-- ════════════════════════════════════════════════════════════════
--  9.  PAGE: SETTINGS
-- ════════════════════════════════════════════════════════════════
local PageSettings = Instance.new("Frame")
PageSettings.Name              = "PageSettings"
PageSettings.Size              = UDim2.new(1, 0, 1, 0)
PageSettings.BackgroundTransparency = 1
PageSettings.Visible           = false
PageSettings.Parent            = Pages

local function settingLabel(text, y)
    local l = Instance.new("TextLabel")
    l.Size              = UDim2.new(1, -32, 0, 20)
    l.Position          = UDim2.new(0, 16, 0, y)
    l.BackgroundTransparency = 1
    l.Text              = text
    l.TextColor3        = C.TEXT
    l.Font              = FONT_SEMI
    l.TextSize          = 13
    l.TextXAlignment    = Enum.TextXAlignment.Left
    l.Parent            = PageSettings
    return l
end

local function settingSubLabel(text, y)
    local l = settingLabel(text, y)
    l.TextColor3 = C.SUBTEXT
    l.Font       = FONT_BODY
    l.TextSize   = 11
    return l
end

settingLabel("ℹ  Hub Information", 16)
settingSubLabel("Version: 1.0  |  Keyless + Keyed  |  by ScriptHub", 40)

settingLabel("🔑  Key Status", 80)

local keyStatusLabel = Instance.new("TextLabel")
keyStatusLabel.Size           = UDim2.new(0, 200, 0, 28)
keyStatusLabel.Position       = UDim2.new(0, 16, 0, 104)
keyStatusLabel.BackgroundColor3 = Color3.fromRGB(20,35,20)
keyStatusLabel.BorderSizePixel  = 0
keyStatusLabel.Text           = keyUnlocked and "✔ Unlocked" or "🔒 Locked"
keyStatusLabel.TextColor3     = keyUnlocked and C.SUCCESS or C.DANGER
keyStatusLabel.Font           = FONT_SEMI
keyStatusLabel.TextSize       = 12
keyStatusLabel.Parent         = PageSettings
Instance.new("UICorner", keyStatusLabel).CornerRadius = UDim.new(0, 6)

-- Clear key button
local ClearKeyBtn = Instance.new("TextButton")
ClearKeyBtn.Size              = UDim2.new(0, 140, 0, 34)
ClearKeyBtn.Position          = UDim2.new(0, 16, 0, 148)
ClearKeyBtn.BackgroundColor3  = Color3.fromRGB(40,20,20)
ClearKeyBtn.BorderSizePixel   = 0
ClearKeyBtn.Text              = "🗑  Clear Saved Key"
ClearKeyBtn.TextColor3        = C.DANGER
ClearKeyBtn.Font              = FONT_SEMI
ClearKeyBtn.TextSize          = 12
ClearKeyBtn.AutoButtonColor   = false
ClearKeyBtn.Parent            = PageSettings
Instance.new("UICorner", ClearKeyBtn).CornerRadius = UDim.new(0, 8)
ClearKeyBtn.MouseButton1Click:Connect(function()
    KeySystem.Clear()
    showToast("🗑  Saved key cleared.", C.WARNING)
end)

settingLabel("📋  Valid Key Format", 200)
settingSubLabel("Keys follow the pattern: MYHUB-XXXX-XXXX", 224)
settingSubLabel("Edit VALID_KEYS in the KeySystem section at the top of Main.lua", 242)

settingLabel("🎮  Main Game Info", 280)
settingSubLabel("Game: "..MainGame.GAME_NAME.."  |  Place ID: "..tostring(MainGame.GAME_PLACE_ID), 304)

settingLabel("➕  Adding Scripts", 344)
settingSubLabel("Add entries to Universal.Scripts or MainGame.Scripts tables inside Main.lua", 368)
settingSubLabel("Each entry needs: name, description, category, code (Lua string)", 386)

-- ════════════════════════════════════════════════════════════════
--  10.  TAB SWITCHING + SEARCH
-- ════════════════════════════════════════════════════════════════
local currentTab = "universal"
local allPages   = {
    universal = PageUniversal,
    maingame  = PageMainGame,
    settings  = PageSettings,
}

local function switchTab(id)
    currentTab = id
    SearchInput.Text = ""
    for tabId, page in pairs(allPages) do
        page.Visible = (tabId == id)
    end
    for tabId, btn in pairs(tabButtons) do
        if tabId == id then
            btn.BackgroundColor3 = C.CARD
            btn.TextColor3       = C.TEXT
        else
            btn.BackgroundColor3 = C.SIDEBAR
            btn.TextColor3       = C.SUBTEXT
        end
    end
end

for tabId, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function() switchTab(tabId) end)
end

-- Search filter
SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local query = SearchInput.Text:lower()

    -- Universal cards
    for _, entry in ipairs(uCards) do
        local match = entry.script.name:lower():find(query,1,true)
                   or entry.script.category:lower():find(query,1,true)
                   or entry.script.description:lower():find(query,1,true)
        entry.frame.Visible = (match ~= nil) or query == ""
    end

    -- Main game cards
    for _, entry in ipairs(mgCards) do
        local match = entry.script.name:lower():find(query,1,true)
                   or entry.script.category:lower():find(query,1,true)
                   or entry.script.description:lower():find(query,1,true)
        entry.frame.Visible = (match ~= nil) or query == ""
    end
end)

-- ════════════════════════════════════════════════════════════════
--  11.  OPEN ANIMATION
-- ════════════════════════════════════════════════════════════════
switchTab("universal")
Window.Size = UDim2.new(0, WIN_W, 0, 0)
TweenService:Create(Window, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    {Size = UDim2.new(0, WIN_W, 0, WIN_H)}):Play()

print("[ScriptHub] Loaded — Universal scripts ready. Enter key for Main Game scripts.")
