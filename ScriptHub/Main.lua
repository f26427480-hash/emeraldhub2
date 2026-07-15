--[[
╔══════════════════════════════════════════════════════════════╗
║              E M E R A L D   H U B   v2.0                   ║
║         Universal (Keyless) + Main Game (Keyed)              ║
║                                                              ║
║  SETUP — change these two values to match your bot:          ║
║    1. HUB_SECRET  (line ~40) — same value as in .env         ║
║    2. MainGame.GAME_NAME / GAME_PLACE_ID (line ~220)         ║
║                                                              ║
║  HOW TO GET A KEY:                                           ║
║    Run /getkey in your Discord server.                       ║
║    The bot DMs you a key valid for 72 hours.                 ║
║    Paste it in the Main Game tab → Unlock.                   ║
║                                                              ║
║  HOW KEYS WORK (no web server needed):                       ║
║    Key = EMERALD-{BASE36_EXPIRY}-{7DIGIT_HASH}              ║
║    Expiry is baked into the key itself.                      ║
║    Hash = hubHash(expiry + HUB_SECRET) — prevents forgery.  ║
║    The hub verifies everything locally, zero HTTP calls.     ║
╚══════════════════════════════════════════════════════════════╝
]]

-- ════════════════════════════════════════════════════════════════
--  0.  SHARED SECRET
--      ▸ Must EXACTLY match HUB_SECRET in your EmeraldBot .env
--      ▸ Change this before distributing your hub
-- ════════════════════════════════════════════════════════════════
local HUB_SECRET = "vsynclandemily"

-- ════════════════════════════════════════════════════════════════
--  1.  KEY SYSTEM
-- ════════════════════════════════════════════════════════════════
local KeySystem = (function()
    local M = {}
    M.KEY_FILE = "EmeraldHub_Key.txt"

    -- Same polynomial hash used in bot.js (mod 1_000_000_007 = safe in both Lua doubles and JS)
    local MOD = 1000000007
    local function hubHash(s)
        local h = 0
        for i = 1, #s do
            h = (h * 31 + s:byte(i)) % MOD
        end
        return string.format("%07d", h)
    end

    -- Decode a base-36 string to a Lua integer
    local function b36decode(s)
        local n = 0
        for i = 1, #s do
            local c = s:sub(i, i):upper()
            local v = tonumber(c) or (c:byte() - 55) -- A=10..Z=35
            n = n * 36 + v
        end
        return n
    end

    -- Returns ok (bool), message (string), secondsRemaining (number or nil)
    function M.Validate(input)
        if not input or input == "" then
            return false, "No key entered.", nil
        end
        local key = input:gsub("%s+", ""):upper()
        -- Expected format: EMERALD-{BASE36}-{7DIGITS}
        local expB36, hash = key:match("^EMERALD%-([A-Z0-9]+)%-(%d%d%d%d%d%d%d)$")
        if not expB36 then
            return false, "Invalid format. Keys look like:\nEMERALD-XXXXX-0000000", nil
        end
        -- Verify signature first
        local expected = hubHash(expB36 .. HUB_SECRET)
        if hash ~= expected then
            return false, "Invalid key — not issued by EmeraldHub.", nil
        end
        -- Check expiry
        local expiry = b36decode(expB36)
        local remaining = expiry - os.time()
        if remaining <= 0 then
            return false, "Key expired. Run /getkey in Discord for a new one.", nil
        end
        local hrs  = math.floor(remaining / 3600)
        local mins = math.floor((remaining % 3600) / 60)
        return true, string.format("Key valid — %dh %dm remaining.", hrs, mins), remaining
    end

    -- Save raw key text locally so user doesn't retype every session
    function M.Save(key)
        pcall(writefile, M.KEY_FILE, key:upper():gsub("%s+", ""))
    end

    -- Load saved key or nil
    function M.Load()
        local ok, data = pcall(readfile, M.KEY_FILE)
        if ok and data and data ~= "" then return data end
        return nil
    end

    function M.Clear()
        pcall(delfile, M.KEY_FILE)
    end

    return M
end)()

-- ════════════════════════════════════════════════════════════════
--  2.  UNIVERSAL SCRIPTS  (keyless)
-- ════════════════════════════════════════════════════════════════
local Universal = {}
Universal.Scripts = {
    -- ── MOVEMENT ──────────────────────────────────────────────
    {name="Infinite Jump",     description="Jump again in mid-air.",                              category="Movement",
     code=[[
local UIS=game:GetService("UserInputService")
local lp=game:GetService("Players").LocalPlayer
UIS.JumpRequest:Connect(function()
    local hum=lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
print("[EmeraldHub] Infinite Jump ON")
]]},
    {name="WalkSpeed x3",      description="Sets WalkSpeed to 48 (3× default).",                 category="Movement",
     code=[[
local lp=game:GetService("Players").LocalPlayer
local function s() local h=lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") if h then h.WalkSpeed=48 end end
s() lp.CharacterAdded:Connect(function(c) c:WaitForChild("Humanoid").WalkSpeed=48 end)
print("[EmeraldHub] WalkSpeed → 48")
]]},
    {name="High Jump",         description="Sets JumpPower to 120.",                              category="Movement",
     code=[[
local lp=game:GetService("Players").LocalPlayer
local function s() local h=lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") if h then h.JumpPower=120 end end
s() lp.CharacterAdded:Connect(function(c) c:WaitForChild("Humanoid").JumpPower=120 end)
print("[EmeraldHub] JumpPower → 120")
]]},
    {name="Fly  [Hold Q]",     description="Hold Q to fly. WASD + Space/Ctrl to steer.",         category="Movement",
     code=[[
local UIS=game:GetService("UserInputService") local RS=game:GetService("RunService")
local lp=game:GetService("Players").LocalPlayer local cam=workspace.CurrentCamera
local flying=false local bv,bg
local function start()
    local r=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") if not r then return end
    bv=Instance.new("BodyVelocity",r) bv.MaxForce=Vector3.new(1e5,1e5,1e5) bv.Velocity=Vector3.new(0,0,0)
    bg=Instance.new("BodyGyro",r) bg.MaxTorque=Vector3.new(1e5,1e5,1e5) bg.P=1e4 flying=true
end
local function stop() if bv then bv:Destroy() end if bg then bg:Destroy() end flying=false end
UIS.InputBegan:Connect(function(i,g) if g then return end if i.KeyCode==Enum.KeyCode.Q then start() end end)
UIS.InputEnded:Connect(function(i) if i.KeyCode==Enum.KeyCode.Q then stop() end end)
RS.RenderStepped:Connect(function()
    if not flying or not bv then return end
    local r=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") if not r then return end
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
print("[EmeraldHub] Fly ON — hold Q")
]]},
    {name="Noclip  [N]",       description="Toggle noclip with the N key.",                      category="Movement",
     code=[[
local UIS=game:GetService("UserInputService") local RS=game:GetService("RunService")
local lp=game:GetService("Players").LocalPlayer local nc=false
UIS.InputBegan:Connect(function(i,g) if g then return end if i.KeyCode==Enum.KeyCode.N then nc=not nc print("[EmeraldHub] Noclip "..(nc and "ON" or "OFF")) end end)
RS.Stepped:Connect(function() if nc and lp.Character then for _,p in ipairs(lp.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end end)
]]},
    -- ── VISUAL ────────────────────────────────────────────────
    {name="Player ESP",        description="Highlights all players in red.",                      category="Visual",
     code=[[
local Players=game:GetService("Players") local lp=Players.LocalPlayer local store={}
local function make(c) local h=Instance.new("Highlight") h.FillColor=Color3.fromRGB(16,185,129) h.OutlineColor=Color3.fromRGB(255,255,255) h.FillTransparency=0.45 h.Parent=c return h end
local function add(p) if p==lp then return end
    local function onC(c) if store[p] then store[p]:Destroy() end store[p]=make(c) end
    if p.Character then onC(p.Character) end
    p.CharacterAdded:Connect(onC)
    p.CharacterRemoving:Connect(function() if store[p] then store[p]:Destroy() store[p]=nil end end)
end
for _,p in ipairs(Players:GetPlayers()) do add(p) end
Players.PlayerAdded:Connect(add)
print("[EmeraldHub] Player ESP ON")
]]},
    {name="Fullbright",        description="Max ambient lighting — no more dark areas.",          category="Visual",
     code=[[
local L=game:GetService("Lighting") L.Brightness=2 L.ClockTime=14 L.FogEnd=1e6 L.GlobalShadows=false
L.Ambient=Color3.fromRGB(178,178,178) L.OutdoorAmbient=Color3.fromRGB(178,178,178)
print("[EmeraldHub] Fullbright ON")
]]},
    {name="FOV → 90",          description="Sets camera field of view to 90.",                   category="Visual",
     code=[[workspace.CurrentCamera.FieldOfView=90 print("[EmeraldHub] FOV → 90")]]},
    -- ── UTILITY ───────────────────────────────────────────────
    {name="Anti-AFK",          description="Prevents the idle kick.",                            category="Utility",
     code=[[
local VU=game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    VU:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
    task.wait(1) VU:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
end)
print("[EmeraldHub] Anti-AFK ON")
]]},
    {name="Rejoin",            description="Instantly rejoins the current game.",                 category="Utility",
     code=[[game:GetService("TeleportService"):Teleport(game.PlaceId,game:GetService("Players").LocalPlayer)]]},
    {name="Copy Server Link",  description="Copies a direct join link to clipboard.",             category="Utility",
     code=[[
setclipboard("roblox://experiences/start?placeId="..game.PlaceId.."&gameInstanceId="..game.JobId)
print("[EmeraldHub] Server link copied!")
]]},
    {name="Hide Character",    description="Makes your character invisible locally.",             category="Utility",
     code=[[
local c=game:GetService("Players").LocalPlayer.Character or game:GetService("Players").LocalPlayer.CharacterAdded:Wait()
for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") or p:IsA("Decal") then p.Transparency=1 end end
print("[EmeraldHub] Character hidden")
]]},
}

-- ════════════════════════════════════════════════════════════════
--  3.  MAIN GAME SCRIPTS  (keyed — 72hr key from Discord bot)
-- ════════════════════════════════════════════════════════════════
local MainGame = {}
MainGame.GAME_NAME     = "Blox Fruits"
MainGame.GAME_PLACE_ID = 2753915549

MainGame.Scripts = {
    -- ── FARM ──────────────────────────────────────────────────
    {name="Auto Farm (Quest)",  description="Kills quest enemies automatically.",                 category="Farm",
     code=[[
local lp=game:GetService("Players").LocalPlayer
local char=lp.Character or lp.CharacterAdded:Wait()
local hum=char:WaitForChild("Humanoid") local root=char:WaitForChild("HumanoidRootPart")
local running=true
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
print("[EmeraldHub] Auto Farm ON") 
while running and task.wait(0.15) do
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
    {name="Auto Eat Fruit",     description="Eats any Devil Fruit that spawns on the ground.",   category="Farm",
     code=[[
local lp=game:GetService("Players").LocalPlayer
local char=lp.Character or lp.CharacterAdded:Wait()
local root=char:WaitForChild("HumanoidRootPart")
local function eat(o)
    if o.Name:find("Fruit") then
        local r=o:FindFirstChild("Handle") or o:FindFirstChildOfClass("Part")
        if r then root.CFrame=r.CFrame+Vector3.new(0,2,0) firetouchinterest(root,r,0) task.wait(0.2) firetouchinterest(root,r,1) print("[EmeraldHub] Ate: "..o.Name) end
    end
end
for _,o in ipairs(workspace:GetDescendants()) do eat(o) end
workspace.DescendantAdded:Connect(function(o) task.wait(0.5) eat(o) end)
print("[EmeraldHub] Auto Eat Fruit ON")
]]},
    -- ── ESP ────────────────────────────────────────────────────
    {name="Fruit ESP",          description="Gold highlights on all Devil Fruits.",               category="ESP",
     code=[[
local function hl()
    for _,o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Model") and o.Name:find("Fruit") and not o:FindFirstChildOfClass("Highlight") then
            local h=Instance.new("Highlight") h.FillColor=Color3.fromRGB(255,215,0) h.OutlineColor=Color3.fromRGB(255,255,255) h.FillTransparency=0.3 h.Parent=o
        end
    end
end
hl() workspace.DescendantAdded:Connect(function() task.wait(0.2) hl() end) print("[EmeraldHub] Fruit ESP ON")
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
workspace.DescendantAdded:Connect(add) print("[EmeraldHub] Boss ESP ON")
]]},
    -- ── TELEPORT ──────────────────────────────────────────────
    {name="TP to Sea 1",        description="Teleports your character to the Sea 1 island.",     category="Teleport",
     code=[[
local r=game:GetService("Players").LocalPlayer.Character:WaitForChild("HumanoidRootPart")
r.CFrame=CFrame.new(-1270,40,1760) print("[EmeraldHub] Teleported to Sea 1")
]]},
    -- ── COMBAT ────────────────────────────────────────────────
    {name="Kill Aura  [Sword]", description="Hits enemies within 10 studs with your sword.",     category="Combat",
     code=[[
local lp=game:GetService("Players").LocalPlayer local RS=game:GetService("RunService")
RS.Heartbeat:Connect(function()
    local char=lp.Character if not char then return end
    local root=char:FindFirstChild("HumanoidRootPart") local tool=char:FindFirstChildOfClass("Tool")
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
print("[EmeraldHub] Kill Aura ON")
]]},
    -- ── STATS ─────────────────────────────────────────────────
    {name="Dump Stats → Melee", description="Puts all unspent stat points into Melee.",          category="Stats",
     code=[[
local lp=game:GetService("Players").LocalPlayer
local remote=game:GetService("ReplicatedStorage"):FindFirstChild("Stat",true)
if remote then
    local data=lp:WaitForChild("Data",10)
    if data then
        local pts=data:FindFirstChild("StatPoints") or data:FindFirstChild("Points")
        if pts then for i=1,pts.Value do remote:FireServer("Melee") end print("[EmeraldHub] "..pts.Value.." → Melee") end
    end
else print("[EmeraldHub] Stat remote not found for this patch") end
]]},
    -- ── MISC ──────────────────────────────────────────────────
    {name="Auto Accept Trade",  description="Accepts all incoming trade requests.",              category="Misc",
     code=[[
game:GetService("ReplicatedStorage").DescendantAdded:Connect(function(o)
    if o.Name:find("Trade") then
        task.wait(0.5)
        local r=game:GetService("ReplicatedStorage"):FindFirstChild("AcceptTrade",true)
        if r then r:FireServer() end
    end
end)
print("[EmeraldHub] Auto Accept Trade ON")
]]},
}

-- ════════════════════════════════════════════════════════════════
--  4.  CLEANUP — destroy stale hub if re-executed
-- ════════════════════════════════════════════════════════════════
for _, name in ipairs({"EmeraldHub_GUI", "ScriptHub_GUI"}) do
    local old = game:GetService("CoreGui"):FindFirstChild(name)
    if old then old:Destroy() end
    local pg  = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if pg then local o2 = pg:FindFirstChild(name) if o2 then o2:Destroy() end end
end

-- ════════════════════════════════════════════════════════════════
--  5.  COLOUR PALETTE — Emerald theme
-- ════════════════════════════════════════════════════════════════
local C = {
    BG       = Color3.fromRGB(10,  14,  20),
    SIDEBAR  = Color3.fromRGB(14,  20,  28),
    CARD     = Color3.fromRGB(18,  26,  36),
    CARDH    = Color3.fromRGB(22,  34,  46),
    ACCENT   = Color3.fromRGB(16,  185, 129),   -- emerald
    ACCENT2  = Color3.fromRGB(5,   150, 105),   -- darker emerald
    DANGER   = Color3.fromRGB(239, 68,  68),
    SUCCESS  = Color3.fromRGB(16,  185, 129),
    WARNING  = Color3.fromRGB(234, 179, 8),
    TEXT     = Color3.fromRGB(236, 253, 245),
    SUBTEXT  = Color3.fromRGB(110, 170, 140),
    INPUT_BG = Color3.fromRGB(16,  24,  32),
    DIVIDER  = Color3.fromRGB(24,  36,  48),
    BADGE_BG = Color3.fromRGB(10,  40,  28),
}
local FONT      = Enum.Font.GothamBold
local FONT_SEMI = Enum.Font.GothamSemibold
local FONT_BODY = Enum.Font.Gotham

-- ════════════════════════════════════════════════════════════════
--  6.  SCREEN GUI
-- ════════════════════════════════════════════════════════════════
local function guiParent()
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    return (ok and cg) or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "EmeraldHub_GUI"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder   = 99
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent         = guiParent()

local WIN_W, WIN_H = 820, 520
local Window = Instance.new("Frame")
Window.Name             = "Window"
Window.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
Window.Position         = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Window.BackgroundColor3 = C.BG
Window.BorderSizePixel  = 0
Window.ClipsDescendants = true
Window.Parent           = ScreenGui
Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 12)

-- Subtle outer glow
local Glow = Instance.new("Frame")
Glow.Size                   = UDim2.new(1, 24, 1, 24)
Glow.Position               = UDim2.new(0, -12, 0, -4)
Glow.BackgroundColor3       = C.ACCENT
Glow.BackgroundTransparency = 0.82
Glow.BorderSizePixel        = 0
Glow.ZIndex                 = 0
Glow.Parent                 = Window
Instance.new("UICorner", Glow).CornerRadius = UDim.new(0, 16)

-- Drag
do
    local dragging, dragStart, startPos = false
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
            local d = input.Position - dragStart
            Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                         startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
--  7.  SIDEBAR
-- ════════════════════════════════════════════════════════════════
local Sidebar = Instance.new("Frame")
Sidebar.Size             = UDim2.new(0, 176, 1, 0)
Sidebar.BackgroundColor3 = C.SIDEBAR
Sidebar.BorderSizePixel  = 0
Sidebar.Parent           = Window
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 12)

-- Right-edge square filler so sidebar flush-connects to content area
local SBFill = Instance.new("Frame")
SBFill.Size             = UDim2.new(0, 12, 1, 0)
SBFill.Position         = UDim2.new(1, -12, 0, 0)
SBFill.BackgroundColor3 = C.SIDEBAR
SBFill.BorderSizePixel  = 0
SBFill.Parent           = Sidebar

-- Logo
local LogoLabel = Instance.new("TextLabel")
LogoLabel.Size           = UDim2.new(1, -16, 0, 26)
LogoLabel.Position       = UDim2.new(0, 10, 0, 16)
LogoLabel.BackgroundTransparency = 1
LogoLabel.Text           = "💎  EMERALD HUB"
LogoLabel.TextColor3     = C.ACCENT
LogoLabel.Font           = FONT
LogoLabel.TextSize       = 15
LogoLabel.TextXAlignment = Enum.TextXAlignment.Left
LogoLabel.Parent         = Sidebar

local VerLabel = Instance.new("TextLabel")
VerLabel.Size            = UDim2.new(1, -16, 0, 14)
VerLabel.Position        = UDim2.new(0, 10, 0, 44)
VerLabel.BackgroundTransparency = 1
VerLabel.Text            = "v2.0  •  72hr Keyed"
VerLabel.TextColor3      = C.SUBTEXT
VerLabel.Font            = FONT_BODY
VerLabel.TextSize        = 11
VerLabel.TextXAlignment  = Enum.TextXAlignment.Left
VerLabel.Parent          = Sidebar

local Divider0 = Instance.new("Frame")
Divider0.Size            = UDim2.new(1, -20, 0, 1)
Divider0.Position        = UDim2.new(0, 10, 0, 68)
Divider0.BackgroundColor3= C.DIVIDER
Divider0.BorderSizePixel = 0
Divider0.Parent          = Sidebar

-- Tab buttons
local NAV = {
    {id="universal", label="🌐  Universal",  sub="No key required"},
    {id="maingame",  label="🔐  "..MainGame.GAME_NAME, sub="72h key from Discord"},
    {id="settings",  label="⚙️  Settings",   sub="Key & hub config"},
}
local tabBtns = {}
for i, tab in ipairs(NAV) do
    local btn = Instance.new("TextButton")
    btn.Name             = "Tab_"..tab.id
    btn.Size             = UDim2.new(1, -14, 0, 52)
    btn.Position         = UDim2.new(0, 7, 0, 76 + (i-1)*58)
    btn.BackgroundColor3 = C.SIDEBAR
    btn.BorderSizePixel  = 0
    btn.Text             = ""
    btn.AutoButtonColor  = false
    btn.Parent           = Sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1, -14, 0, 20)
    lbl.Position         = UDim2.new(0, 12, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Text             = tab.label
    lbl.TextColor3       = C.SUBTEXT
    lbl.Font             = FONT_SEMI
    lbl.TextSize         = 13
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = btn

    local sub = Instance.new("TextLabel")
    sub.Size             = UDim2.new(1, -14, 0, 14)
    sub.Position         = UDim2.new(0, 12, 0, 30)
    sub.BackgroundTransparency = 1
    sub.Text             = tab.sub
    sub.TextColor3       = C.SUBTEXT
    sub.Font             = FONT_BODY
    sub.TextSize         = 10
    sub.TextXAlignment   = Enum.TextXAlignment.Left
    sub.Parent           = btn

    tabBtns[tab.id] = {btn=btn, lbl=lbl, sub=sub}
end

-- Close button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size            = UDim2.new(1, -14, 0, 36)
CloseBtn.Position        = UDim2.new(0, 7, 1, -48)
CloseBtn.BackgroundColor3= Color3.fromRGB(30,14,14)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text            = "✕  Close Hub"
CloseBtn.TextColor3      = C.DANGER
CloseBtn.Font            = FONT_SEMI
CloseBtn.TextSize        = 12
CloseBtn.AutoButtonColor = false
CloseBtn.Parent          = Sidebar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)
local cpd = Instance.new("UIPadding") cpd.PaddingLeft=UDim.new(0,12) cpd.Parent=CloseBtn
CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(Window,TweenInfo.new(0.25,Enum.EasingStyle.Quad),{Size=UDim2.new(0,WIN_W,0,0)}):Play()
    task.wait(0.3) ScreenGui:Destroy()
end)

-- ════════════════════════════════════════════════════════════════
--  8.  CONTENT AREA + TOAST
-- ════════════════════════════════════════════════════════════════
local Content = Instance.new("Frame")
Content.Name             = "Content"
Content.Size             = UDim2.new(1, -176, 1, 0)
Content.Position         = UDim2.new(0, 176, 0, 0)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.Parent           = Window

-- Toast notification
local Toast = Instance.new("Frame")
Toast.Size               = UDim2.new(1, -32, 0, 36)
Toast.Position           = UDim2.new(0, 16, 1, 10)
Toast.BackgroundColor3   = C.SUCCESS
Toast.BorderSizePixel    = 0
Toast.Parent             = Window
Instance.new("UICorner", Toast).CornerRadius = UDim.new(0, 8)
local ToastLbl = Instance.new("TextLabel")
ToastLbl.Size            = UDim2.new(1, -16, 1, 0)
ToastLbl.Position        = UDim2.new(0, 10, 0, 0)
ToastLbl.BackgroundTransparency = 1
ToastLbl.Text            = ""
ToastLbl.TextColor3      = Color3.fromRGB(255,255,255)
ToastLbl.Font            = FONT_SEMI
ToastLbl.TextSize        = 13
ToastLbl.TextXAlignment  = Enum.TextXAlignment.Left
ToastLbl.Parent          = Toast

local toastBusy = false
local function showToast(msg, col, dur)
    if toastBusy then return end
    toastBusy = true
    Toast.BackgroundColor3 = col or C.SUCCESS
    ToastLbl.Text = msg
    TweenService:Create(Toast,TweenInfo.new(0.3,Enum.EasingStyle.Back),{Position=UDim2.new(0,16,1,-50)}):Play()
    task.wait(dur or 2.5)
    TweenService:Create(Toast,TweenInfo.new(0.25),{Position=UDim2.new(0,16,1,10)}):Play()
    task.wait(0.3) toastBusy = false
end

-- Page container
local Pages = Instance.new("Frame")
Pages.Name               = "Pages"
Pages.Size               = UDim2.new(1, 0, 1, 0)
Pages.BackgroundTransparency = 1
Pages.ClipsDescendants   = true
Pages.Parent             = Content

-- ════════════════════════════════════════════════════════════════
--  9.  HELPERS: SCROLL + CARD
-- ════════════════════════════════════════════════════════════════
local function makeScroll(parent)
    local sf = Instance.new("ScrollingFrame")
    sf.Size                  = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency= 1
    sf.BorderSizePixel       = 0
    sf.ScrollBarThickness    = 4
    sf.ScrollBarImageColor3  = C.ACCENT
    sf.CanvasSize            = UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    sf.Parent                = parent

    local layout = Instance.new("UIListLayout")
    layout.Padding   = UDim.new(0,8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent    = sf

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0,16)
    pad.PaddingRight  = UDim.new(0,16)
    pad.PaddingTop    = UDim.new(0,12)
    pad.PaddingBottom = UDim.new(0,12)
    pad.Parent        = sf

    return sf
end

local function makeCard(script, parent, locked)
    local card = Instance.new("Frame")
    card.Size             = UDim2.new(1, 0, 0, 72)
    card.BackgroundColor3 = C.CARD
    card.BorderSizePixel  = 0
    card.Parent           = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    -- Left accent stripe
    local stripe = Instance.new("Frame")
    stripe.Size             = UDim2.new(0, 3, 0.6, 0)
    stripe.Position         = UDim2.new(0, 0, 0.2, 0)
    stripe.BackgroundColor3 = locked and C.WARNING or C.ACCENT
    stripe.BorderSizePixel  = 0
    stripe.Parent           = card
    Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 3)

    -- Category badge
    local badge = Instance.new("TextLabel")
    badge.Size             = UDim2.new(0, 76, 0, 18)
    badge.Position         = UDim2.new(1, -88, 0, 10)
    badge.BackgroundColor3 = C.BADGE_BG
    badge.BorderSizePixel  = 0
    badge.Text             = script.category
    badge.TextColor3       = locked and C.WARNING or C.ACCENT
    badge.Font             = FONT_SEMI
    badge.TextSize         = 10
    badge.Parent           = card
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 5)

    -- Name
    local nameL = Instance.new("TextLabel")
    nameL.Size            = UDim2.new(1, -106, 0, 22)
    nameL.Position        = UDim2.new(0, 16, 0, 10)
    nameL.BackgroundTransparency = 1
    nameL.Text            = script.name
    nameL.TextColor3      = C.TEXT
    nameL.Font            = FONT
    nameL.TextSize        = 14
    nameL.TextXAlignment  = Enum.TextXAlignment.Left
    nameL.Parent          = card

    -- Description
    local descL = Instance.new("TextLabel")
    descL.Size            = UDim2.new(1, -106, 0, 15)
    descL.Position        = UDim2.new(0, 16, 0, 34)
    descL.BackgroundTransparency = 1
    descL.Text            = script.description
    descL.TextColor3      = C.SUBTEXT
    descL.Font            = FONT_BODY
    descL.TextSize        = 11
    descL.TextXAlignment  = Enum.TextXAlignment.Left
    descL.TextTruncate    = Enum.TextTruncate.AtEnd
    descL.Parent          = card

    -- Execute button
    local execBtn = Instance.new("TextButton")
    execBtn.Size            = UDim2.new(0, 88, 0, 26)
    execBtn.Position        = UDim2.new(0, 16, 1, -36)
    execBtn.BackgroundColor3= locked and Color3.fromRGB(36,28,6) or C.ACCENT
    execBtn.BorderSizePixel = 0
    execBtn.Text            = locked and "🔒 Locked" or "▶  Execute"
    execBtn.TextColor3      = locked and C.WARNING or Color3.fromRGB(255,255,255)
    execBtn.Font            = FONT_SEMI
    execBtn.TextSize        = 12
    execBtn.AutoButtonColor = false
    execBtn.Parent          = card
    Instance.new("UICorner", execBtn).CornerRadius = UDim.new(0, 7)

    card.MouseEnter:Connect(function() card.BackgroundColor3 = C.CARDH end)
    card.MouseLeave:Connect(function() card.BackgroundColor3 = C.CARD  end)

    if not locked then
        execBtn.MouseEnter:Connect(function() TweenService:Create(execBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT2}):Play() end)
        execBtn.MouseLeave:Connect(function() TweenService:Create(execBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT}):Play() end)
    end

    return card, execBtn
end

-- ════════════════════════════════════════════════════════════════
--  10.  PAGE: UNIVERSAL
-- ════════════════════════════════════════════════════════════════
local PageUniversal = Instance.new("Frame")
PageUniversal.Size               = UDim2.new(1,0,1,0)
PageUniversal.BackgroundTransparency = 1
PageUniversal.Parent             = Pages

local uScroll = makeScroll(PageUniversal)

for i, s in ipairs(Universal.Scripts) do
    local card, execBtn = makeCard(s, uScroll, false)
    card.LayoutOrder = i
    execBtn.MouseButton1Click:Connect(function()
        local ok, err = pcall(loadstring(s.code))
        task.spawn(function()
            showToast(ok and ("✔  "..s.name.." executed.") or ("✘  "..tostring(err):sub(1,55)),
                      ok and C.SUCCESS or C.DANGER, ok and 2 or 4)
        end)
    end)
end

-- ════════════════════════════════════════════════════════════════
--  11.  PAGE: MAIN GAME  (key gate)
-- ════════════════════════════════════════════════════════════════
local keyUnlocked = false

local PageMainGame = Instance.new("Frame")
PageMainGame.Size               = UDim2.new(1,0,1,0)
PageMainGame.BackgroundTransparency = 1
PageMainGame.Visible            = false
PageMainGame.Parent             = Pages

-- ── Key Gate ─────────────────────────────────────────────────────
local KeyGate = Instance.new("Frame")
KeyGate.Size             = UDim2.new(1,0,1,0)
KeyGate.BackgroundColor3 = C.BG
KeyGate.BorderSizePixel  = 0
KeyGate.ZIndex           = 10
KeyGate.Parent           = PageMainGame
Instance.new("UICorner", KeyGate).CornerRadius = UDim.new(0,12)

local KeyCard = Instance.new("Frame")
KeyCard.Size             = UDim2.new(0,380,0,270)
KeyCard.Position         = UDim2.new(0.5,-190,0.5,-135)
KeyCard.BackgroundColor3 = C.CARD
KeyCard.BorderSizePixel  = 0
KeyCard.ZIndex           = 11
KeyCard.Parent           = KeyGate
Instance.new("UICorner", KeyCard).CornerRadius = UDim.new(0,12)

-- Emerald top stripe on card
local CardStripe = Instance.new("Frame")
CardStripe.Size             = UDim2.new(1,0,0,3)
CardStripe.BackgroundColor3 = C.ACCENT
CardStripe.BorderSizePixel  = 0
CardStripe.ZIndex           = 12
CardStripe.Parent           = KeyCard
Instance.new("UICorner", CardStripe).CornerRadius = UDim.new(0,12)

local KTitle = Instance.new("TextLabel")
KTitle.Size              = UDim2.new(1,-32,0,26)
KTitle.Position          = UDim2.new(0,16,0,20)
KTitle.BackgroundTransparency = 1
KTitle.Text              = "🔐  "..MainGame.GAME_NAME.." — Key Required"
KTitle.TextColor3        = C.TEXT
KTitle.Font              = FONT
KTitle.TextSize          = 16
KTitle.TextXAlignment    = Enum.TextXAlignment.Left
KTitle.ZIndex            = 12
KTitle.Parent            = KeyCard

local KSub = Instance.new("TextLabel")
KSub.Size                = UDim2.new(1,-32,0,34)
KSub.Position            = UDim2.new(0,16,0,52)
KSub.BackgroundTransparency = 1
KSub.Text                = "Run  /getkey  in the Discord server to get a\nfree 72-hour key, then paste it below."
KSub.TextColor3          = C.SUBTEXT
KSub.Font                = FONT_BODY
KSub.TextSize            = 12
KSub.TextXAlignment      = Enum.TextXAlignment.Left
KSub.TextWrapped         = true
KSub.ZIndex              = 12
KSub.Parent              = KeyCard

-- Input box
local KInputFrame = Instance.new("Frame")
KInputFrame.Size             = UDim2.new(1,-32,0,42)
KInputFrame.Position         = UDim2.new(0,16,0,100)
KInputFrame.BackgroundColor3 = C.INPUT_BG
KInputFrame.BorderSizePixel  = 0
KInputFrame.ZIndex           = 12
KInputFrame.Parent           = KeyCard
Instance.new("UICorner", KInputFrame).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke", KInputFrame).Color = C.DIVIDER

local KInput = Instance.new("TextBox")
KInput.Size              = UDim2.new(1,-20,1,0)
KInput.Position          = UDim2.new(0,10,0,0)
KInput.BackgroundTransparency = 1
KInput.PlaceholderText   = "EMERALD-XXXXX-0000000"
KInput.PlaceholderColor3 = C.SUBTEXT
KInput.Text              = ""
KInput.TextColor3        = C.ACCENT
KInput.Font              = Enum.Font.Code
KInput.TextSize          = 13
KInput.TextXAlignment    = Enum.TextXAlignment.Left
KInput.ZIndex            = 13
KInput.Parent            = KInputFrame

local KStatus = Instance.new("TextLabel")
KStatus.Size             = UDim2.new(1,-32,0,18)
KStatus.Position         = UDim2.new(0,16,0,152)
KStatus.BackgroundTransparency = 1
KStatus.Text             = ""
KStatus.TextColor3       = C.SUBTEXT
KStatus.Font             = FONT_SEMI
KStatus.TextSize         = 12
KStatus.TextXAlignment   = Enum.TextXAlignment.Left
KStatus.ZIndex           = 12
KStatus.Parent           = KeyCard

-- Unlock button
local KBtn = Instance.new("TextButton")
KBtn.Size                = UDim2.new(1,-32,0,42)
KBtn.Position            = UDim2.new(0,16,0,182)
KBtn.BackgroundColor3    = C.ACCENT
KBtn.BorderSizePixel     = 0
KBtn.Text                = "Unlock  "..MainGame.GAME_NAME.."  Scripts"
KBtn.TextColor3          = Color3.fromRGB(255,255,255)
KBtn.Font                = FONT
KBtn.TextSize            = 14
KBtn.AutoButtonColor     = false
KBtn.ZIndex              = 12
KBtn.Parent              = KeyCard
Instance.new("UICorner", KBtn).CornerRadius = UDim.new(0,8)
KBtn.MouseEnter:Connect(function() TweenService:Create(KBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT2}):Play() end)
KBtn.MouseLeave:Connect(function() TweenService:Create(KBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT}):Play() end)

-- Expiry label under button (shown after unlock)
local ExpiryLabel = Instance.new("TextLabel")
ExpiryLabel.Size             = UDim2.new(1,-32,0,16)
ExpiryLabel.Position         = UDim2.new(0,16,0,236)
ExpiryLabel.BackgroundTransparency = 1
ExpiryLabel.Text             = ""
ExpiryLabel.TextColor3       = C.SUBTEXT
ExpiryLabel.Font             = FONT_BODY
ExpiryLabel.TextSize         = 10
ExpiryLabel.TextXAlignment   = Enum.TextXAlignment.Left
ExpiryLabel.ZIndex           = 12
ExpiryLabel.Parent           = KeyCard

-- Script scroll (revealed after key unlock)
local mgScroll = makeScroll(PageMainGame)
mgScroll.Visible = false

local mgCards = {}
for i, s in ipairs(MainGame.Scripts) do
    local card, execBtn = makeCard(s, mgScroll, true)
    card.LayoutOrder = i
    table.insert(mgCards, {script=s, card=card, execBtn=execBtn})
end

-- ── Key validation & unlock logic ────────────────────────────────
local function unlock(remaining)
    keyUnlocked = true
    local hrs  = math.floor(remaining / 3600)
    local mins = math.floor((remaining % 3600) / 60)
    ExpiryLabel.Text = string.format("Key expires in %dh %dm — run /getkey in Discord to renew.", hrs, mins)

    TweenService:Create(KeyGate,TweenInfo.new(0.35,Enum.EasingStyle.Quad),{BackgroundTransparency=1}):Play()
    task.wait(0.1)
    TweenService:Create(KeyCard,TweenInfo.new(0.25),{BackgroundTransparency=1}):Play()
    task.wait(0.3)
    KeyGate.Visible  = false
    mgScroll.Visible = true

    for _, entry in ipairs(mgCards) do
        entry.execBtn.BackgroundColor3 = C.ACCENT
        entry.execBtn.Text             = "▶  Execute"
        entry.execBtn.TextColor3       = Color3.fromRGB(255,255,255)
        entry.execBtn.MouseEnter:Connect(function() TweenService:Create(entry.execBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT2}):Play() end)
        entry.execBtn.MouseLeave:Connect(function() TweenService:Create(entry.execBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT}):Play() end)
        entry.execBtn.MouseButton1Click:Connect(function()
            local s = entry.script
            local ok, err = pcall(loadstring(s.code))
            task.spawn(function()
                showToast(ok and ("✔  "..s.name.." executed.") or ("✘  "..tostring(err):sub(1,55)),
                          ok and C.SUCCESS or C.DANGER, ok and 2 or 4)
            end)
        end)
    end
    showToast("💎  "..MainGame.GAME_NAME.." unlocked!", C.SUCCESS, 3)
end

local function tryKey(raw)
    KStatus.TextColor3 = C.SUBTEXT
    KStatus.Text       = "Verifying…"
    task.wait(0.35)

    local ok, msg, remaining = KeySystem.Validate(raw)
    if ok then
        KeySystem.Save(raw)
        KStatus.TextColor3 = C.SUCCESS
        KStatus.Text       = "✔  " .. msg
        task.wait(0.4)
        unlock(remaining)
    else
        KStatus.TextColor3 = C.DANGER
        KStatus.Text       = "✘  " .. msg
        -- shake
        for _ = 1, 3 do
            TweenService:Create(KInputFrame,TweenInfo.new(0.05),{Position=UDim2.new(0,22,0,100)}):Play() task.wait(0.05)
            TweenService:Create(KInputFrame,TweenInfo.new(0.05),{Position=UDim2.new(0,10,0,100)}):Play() task.wait(0.05)
        end
        TweenService:Create(KInputFrame,TweenInfo.new(0.08),{Position=UDim2.new(0,16,0,100)}):Play()
    end
end

KBtn.MouseButton1Click:Connect(function() tryKey(KInput.Text) end)
KInput.FocusLost:Connect(function(enter) if enter then tryKey(KInput.Text) end end)

-- Auto-load saved key
task.spawn(function()
    local saved = KeySystem.Load()
    if saved then
        KInput.Text = saved
        KStatus.Text = "Found saved key — verifying…"
        task.wait(1) -- let GUI appear first
        tryKey(saved)
    end
end)

-- ════════════════════════════════════════════════════════════════
--  12.  PAGE: SETTINGS
-- ════════════════════════════════════════════════════════════════
local PageSettings = Instance.new("Frame")
PageSettings.Size               = UDim2.new(1,0,1,0)
PageSettings.BackgroundTransparency = 1
PageSettings.Visible            = false
PageSettings.Parent             = Pages

local function settRow(y, label, value, valueColor)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,-32,0,40)
    row.Position         = UDim2.new(0,16,0,y)
    row.BackgroundColor3 = C.CARD
    row.BorderSizePixel  = 0
    row.Parent           = PageSettings
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(0.5,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label
    lbl.TextColor3       = C.SUBTEXT
    lbl.Font             = FONT_BODY
    lbl.TextSize         = 12
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    local p = Instance.new("UIPadding") p.PaddingLeft=UDim.new(0,12) p.Parent=lbl
    lbl.Parent           = row

    local val = Instance.new("TextLabel")
    val.Size             = UDim2.new(0.5,-12,1,0)
    val.Position         = UDim2.new(0.5,0,0,0)
    val.BackgroundTransparency = 1
    val.Text             = value
    val.TextColor3       = valueColor or C.TEXT
    val.Font             = FONT_SEMI
    val.TextSize         = 12
    val.TextXAlignment   = Enum.TextXAlignment.Right
    local p2 = Instance.new("UIPadding") p2.PaddingRight=UDim.new(0,12) p2.Parent=val
    val.Parent           = row
    return val
end

local function sectHeader(y, text)
    local h = Instance.new("TextLabel")
    h.Size             = UDim2.new(1,-32,0,22)
    h.Position         = UDim2.new(0,16,0,y)
    h.BackgroundTransparency = 1
    h.Text             = text
    h.TextColor3       = C.ACCENT
    h.Font             = FONT
    h.TextSize         = 12
    h.TextXAlignment   = Enum.TextXAlignment.Left
    h.Parent           = PageSettings
end

sectHeader(12, "ℹ  HUB INFO")
settRow(36,  "Version",        "2.0")
settRow(84,  "Key Type",       "72-hour self-signing",  C.WARNING)
settRow(132, "Target Game",    MainGame.GAME_NAME,      C.ACCENT)
settRow(180, "Keyless Scripts", tostring(#Universal.Scripts).." scripts",  C.SUCCESS)
settRow(228, "Keyed Scripts",  tostring(#MainGame.Scripts).." scripts",   C.SUCCESS)

sectHeader(284, "🔑  KEY STATUS")
local keyValRow = settRow(308, "Current Key", keyUnlocked and "✔ Unlocked" or "🔒 Locked",
                           keyUnlocked and C.SUCCESS or C.DANGER)

-- Clear saved key
local ClearBtn = Instance.new("TextButton")
ClearBtn.Size            = UDim2.new(1,-32,0,40)
ClearBtn.Position        = UDim2.new(0,16,0,356)
ClearBtn.BackgroundColor3= Color3.fromRGB(30,12,12)
ClearBtn.BorderSizePixel = 0
ClearBtn.Text            = "🗑  Clear Saved Key"
ClearBtn.TextColor3      = C.DANGER
ClearBtn.Font            = FONT_SEMI
ClearBtn.TextSize        = 13
ClearBtn.AutoButtonColor = false
ClearBtn.Parent          = PageSettings
Instance.new("UICorner", ClearBtn).CornerRadius = UDim.new(0,8)
ClearBtn.MouseButton1Click:Connect(function()
    KeySystem.Clear()
    showToast("🗑  Saved key cleared. Run /getkey in Discord for a new one.", C.WARNING, 3)
end)

sectHeader(412, "💬  HOW TO GET A KEY")
local howTo = Instance.new("TextLabel")
howTo.Size             = UDim2.new(1,-32,0,60)
howTo.Position         = UDim2.new(0,16,0,434)
howTo.BackgroundTransparency = 1
howTo.Text             = "1. Join the Discord server\n2. Run  /getkey  in the key channel\n3. The bot DMs you a key  (valid 72 hours)\n4. Paste it in the Main Game tab → Unlock"
howTo.TextColor3       = C.SUBTEXT
howTo.Font             = FONT_BODY
howTo.TextSize         = 12
howTo.TextXAlignment   = Enum.TextXAlignment.Left
howTo.TextWrapped      = true
howTo.Parent           = PageSettings

-- ════════════════════════════════════════════════════════════════
--  13.  TAB SWITCHING
-- ════════════════════════════════════════════════════════════════
local allPages = {
    universal = PageUniversal,
    maingame  = PageMainGame,
    settings  = PageSettings,
}
local currentTab = "universal"

local function switchTab(id)
    currentTab = id
    for tid, page in pairs(allPages) do
        page.Visible = (tid == id)
    end
    for tid, t in pairs(tabBtns) do
        local active = (tid == id)
        TweenService:Create(t.btn, TweenInfo.new(0.15), {
            BackgroundColor3 = active and C.CARD or C.SIDEBAR
        }):Play()
        t.lbl.TextColor3 = active and C.TEXT   or C.SUBTEXT
        t.sub.TextColor3 = active and C.ACCENT or C.SUBTEXT
    end
    -- Refresh settings key status whenever settings tab is opened
    if id == "settings" then
        keyValRow.Text      = keyUnlocked and "✔ Unlocked" or "🔒 Locked"
        keyValRow.TextColor3= keyUnlocked and C.SUCCESS or C.DANGER
    end
end

for tabId, t in pairs(tabBtns) do
    t.btn.MouseButton1Click:Connect(function() switchTab(tabId) end)
end

-- ════════════════════════════════════════════════════════════════
--  14.  OPEN ANIMATION
-- ════════════════════════════════════════════════════════════════
switchTab("universal")
Window.Size = UDim2.new(0, WIN_W, 0, 0)
TweenService:Create(Window, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    {Size = UDim2.new(0, WIN_W, 0, WIN_H)}):Play()

print("[EmeraldHub] Loaded — run /getkey in Discord to unlock "..MainGame.GAME_NAME.." scripts.")
