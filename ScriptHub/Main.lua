--[[
╔══════════════════════════════════════════════════════════════╗
║              E M E R A L D   H U B   v2.1                   ║
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

    local MOD = 1000000007
    local function hubHash(s)
        local h = 0
        for i = 1, #s do
            h = (h * 31 + s:byte(i)) % MOD
        end
        -- Clamp to exactly 7 digits — MOD can produce up to 10 digits
        -- which breaks the EMERALD-...-\d{7} regex match.
        return string.format("%07d", h % 10000000)
    end

    local function b36decode(s)
        local n = 0
        for i = 1, #s do
            local c = s:sub(i, i):upper()
            local v = tonumber(c) or (c:byte() - 55)
            n = n * 36 + v
        end
        return n
    end

    function M.Validate(input)
        if not input or input == "" then return false, "No key entered.", nil end
        local key = input:gsub("%s+", ""):upper()
        local expB36, hash = key:match("^EMERALD%-([A-Z0-9]+)%-(%d%d%d%d%d%d%d)$")
        if not expB36 then return false, "Invalid format. Keys look like:\nEMERALD-XXXXX-0000000", nil end
        local expected = hubHash(expB36 .. HUB_SECRET)
        if hash ~= expected then return false, "Invalid key — not issued by EmeraldHub.", nil end
        local expiry = b36decode(expB36)
        local remaining = expiry - os.time()
        if remaining <= 0 then return false, "Key expired. Run /getkey in Discord for a new one.", nil end
        local hrs  = math.floor(remaining / 3600)
        local mins = math.floor((remaining % 3600) / 60)
        return true, string.format("Key valid — %dh %dm remaining.", hrs, mins), remaining
    end

    function M.Save(key)  pcall(writefile, M.KEY_FILE, key:upper():gsub("%s+", "")) end
    function M.Load()
        local ok, data = pcall(readfile, M.KEY_FILE)
        if ok and data and data ~= "" then return data end
        return nil
    end
    function M.Clear() pcall(delfile, M.KEY_FILE) end
    return M
end)()

-- ════════════════════════════════════════════════════════════════
--  2.  UNIVERSAL SCRIPTS  (keyless)
-- ════════════════════════════════════════════════════════════════
local Universal = {}
Universal.Scripts = {
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
--  3.  GAME LIBRARY  (keyed — auto-detected from game.PlaceId)
-- ════════════════════════════════════════════════════════════════
local GAME_LIBRARY = {
    [142823291] = { name = "Murder Mystery 2", scripts = {
        {name="⭐  MM2 Script",       description="ESP, role reveal, gun mods & more.",                category="Featured",
         code=[[loadstring(game:HttpGet("https://raw.githubusercontent.com/Joystickplays/psychic-octo-invention/main/yarhm.lua", false))()]]},
    }},
    [95082159892680] = { name = "Speed / Keyboard Escape", scripts = {
        {name="⭐  LuxyHub",          description="Multi-feature hub for Speed / Keyboard Escape.",    category="Featured",
         code=[[loadstring(game:HttpGet("https://www.luxyhub.space/api/loader/luxyhub"))()]]},
    }},
    [9391468976] = { name = "Jjs", scripts = {
        {name="⭐  Jjs Script",       description="Main script for Jjs.",                              category="Featured",
         code=[[loadstring(game:HttpGet("https://raw.githubusercontent.com/NeziaReal/jjs/refs/heads/main/main.lua"))()]]},
    }},
    [78515283254292] = { name = "Animal Hospital", scripts = {
        {name="⭐  Animal Hospital",  description="Auto-play script for Animal Hospital.",             category="Featured",
         code=[[loadstring(game:HttpGet("https://raw.githubusercontent.com/caomod2077/Script/refs/heads/main/FN_AnimalHospital.lua"))()]]},
    }},
    [99567941238278] = { name = "Ink Game", scripts = {
        {name="⭐  Ink Game Script",  description="Main script for Ink Game.",                         category="Featured",
         code=[[loadstring(game:HttpGet("https://raw.githubusercontent.com/wefwef127382/inkgames.github.io/refs/heads/main/ringta.lua"))()]]},
    }},
}

local _placeId = game.PlaceId
local _entry   = GAME_LIBRARY[_placeId]
local MainGame = nil
if _entry then
    MainGame = { GAME_NAME = _entry.name, GAME_PLACE_ID = _placeId, Scripts = _entry.scripts }
end

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
    ACCENT   = Color3.fromRGB(16,  185, 129),
    ACCENT2  = Color3.fromRGB(5,   150, 105),
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
--  5b. SERVICES & MOBILE DETECTION
-- ════════════════════════════════════════════════════════════════
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")

local PLATFORM  = UIS:GetPlatform()
local isMobile  = PLATFORM == Enum.Platform.IOS
               or PLATFORM == Enum.Platform.Android
               or PLATFORM == Enum.Platform.UWP

-- Layout constants — adapt per platform
local CAM        = workspace.CurrentCamera
local VPS        = CAM.ViewportSize
local WIN_W      = isMobile and VPS.X  or 820
local WIN_H      = isMobile and VPS.Y  or 520
local SIDEBAR_W  = isMobile and 0      or 176  -- sidebar hidden on mobile
local BOTTOM_H   = isMobile and 54     or 0    -- bottom nav on mobile
local CARD_H     = isMobile and 82     or 72   -- taller touch targets
local BTN_H      = isMobile and 34     or 26
local BTN_TS     = isMobile and 14     or 12
local LOGO_TS    = isMobile and 14     or 15

-- ════════════════════════════════════════════════════════════════
--  5c. MUSIC SYSTEM
--      Replace the 0 IDs below with your actual Roblox audio IDs.
--      Find them on the audio page: roblox.com/catalog?Category=Audio
--      Example: if the URL is /catalog/1234567890/Song-Name use 1234567890
-- ════════════════════════════════════════════════════════════════
local MUSIC_PLAYLIST = {
    { name = "Misery",      id = 1838776351 },
    { name = "Meant to Be", id = 138323881451411 },
}
local _musicIdx = 1

task.spawn(function()
    local SS  = game:GetService("SoundService")
    -- Remove any stale music from a previous execution
    local old = SS:FindFirstChild("EmeraldHub_Music")
    if old then old:Destroy() end

    local snd = Instance.new("Sound")
    snd.Name   = "EmeraldHub_Music"
    snd.Volume = 0.35
    snd.RollOffMaxDistance = 1e6
    snd.Parent = SS

    local function playNext()
        local track = MUSIC_PLAYLIST[_musicIdx]
        _musicIdx = (_musicIdx % #MUSIC_PLAYLIST) + 1
        if track and track.id ~= 0 then
            snd.SoundId = "rbxassetid://" .. track.id
            snd:Play()
        end
    end

    playNext()
    snd.Ended:Connect(function() task.wait(0.3) playNext() end)
end)

-- ════════════════════════════════════════════════════════════════
--  6.  SCREEN GUI
-- ════════════════════════════════════════════════════════════════
local function guiParent()
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    return (ok and cg) or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "EmeraldHub_GUI"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder   = 99
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent         = guiParent()

-- ── Window frame ──────────────────────────────────────────────
local Window = Instance.new("Frame")
Window.Name             = "Window"
Window.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
Window.BackgroundColor3 = C.BG
Window.BorderSizePixel  = 0
Window.ClipsDescendants = true
Window.Parent           = ScreenGui

if isMobile then
    -- Full screen, anchored top-left
    Window.Position = UDim2.new(0, 0, 0, 0)
    Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 0)
else
    -- Centered floating window with rounded corners
    Window.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
    Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 12)

    -- Subtle outer glow (desktop only)
    local Glow = Instance.new("Frame")
    Glow.Size                   = UDim2.new(1, 24, 1, 24)
    Glow.Position               = UDim2.new(0, -12, 0, -4)
    Glow.BackgroundColor3       = C.ACCENT
    Glow.BackgroundTransparency = 0.82
    Glow.BorderSizePixel        = 0
    Glow.ZIndex                 = 0
    Glow.Parent                 = Window
    Instance.new("UICorner", Glow).CornerRadius = UDim.new(0, 16)
end

-- ── Drag (desktop only) ───────────────────────────────────────
if not isMobile then
    local dragging, dragStart, startPos = false
    Window.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = Window.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                         startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
--  6b. LOADING SCREEN
-- ════════════════════════════════════════════════════════════════
local LoadScreen = Instance.new("Frame")
LoadScreen.Name              = "LoadScreen"
LoadScreen.Size              = UDim2.new(1, 0, 1, 0)
LoadScreen.BackgroundColor3  = C.BG
LoadScreen.BorderSizePixel   = 0
LoadScreen.ZIndex            = 200
LoadScreen.Parent            = Window

-- Emerald diamond / logo
local LLogo = Instance.new("TextLabel")
LLogo.Size                  = UDim2.new(0.8, 0, 0, 44)
LLogo.Position              = UDim2.new(0.1, 0, 0.38, 0)
LLogo.BackgroundTransparency = 1
LLogo.Text                  = "💎  EMERALD HUB"
LLogo.TextColor3            = C.ACCENT
LLogo.Font                  = FONT
LLogo.TextSize              = isMobile and 30 or 26
LLogo.ZIndex                = 201
LLogo.Parent                = LoadScreen

local LVer = Instance.new("TextLabel")
LVer.Size                   = UDim2.new(0.8, 0, 0, 20)
LVer.Position               = UDim2.new(0.1, 0, 0.38, 50)
LVer.BackgroundTransparency = 1
LVer.Text                   = "v2.1  •  72hr Keyed"
LVer.TextColor3             = C.SUBTEXT
LVer.Font                   = FONT_BODY
LVer.TextSize               = 13
LVer.ZIndex                 = 201
LVer.Parent                 = LoadScreen

local LSub = Instance.new("TextLabel")
LSub.Size                   = UDim2.new(0.8, 0, 0, 18)
LSub.Position               = UDim2.new(0.1, 0, 0.38, 80)
LSub.BackgroundTransparency = 1
LSub.Text                   = "Loading scripts…"
LSub.TextColor3             = C.SUBTEXT
LSub.Font                   = FONT_BODY
LSub.TextSize               = 12
LSub.ZIndex                 = 201
LSub.Parent                 = LoadScreen

-- Progress bar
local LBarW  = isMobile and 240 or 200
local LBarBG = Instance.new("Frame")
LBarBG.Size             = UDim2.new(0, LBarW, 0, 4)
LBarBG.Position         = UDim2.new(0.5, -LBarW/2, 0.38, 108)
LBarBG.BackgroundColor3 = C.DIVIDER
LBarBG.BorderSizePixel  = 0
LBarBG.ZIndex           = 201
LBarBG.Parent           = LoadScreen
Instance.new("UICorner", LBarBG).CornerRadius = UDim.new(0, 2)

local LBar = Instance.new("Frame")
LBar.Size             = UDim2.new(0, 0, 1, 0)
LBar.BackgroundColor3 = C.ACCENT
LBar.BorderSizePixel  = 0
LBar.ZIndex           = 202
LBar.Parent           = LBarBG
Instance.new("UICorner", LBar).CornerRadius = UDim.new(0, 2)

-- Animate and dismiss
task.spawn(function()
    TweenService:Create(LBar, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(1, 0, 1, 0)}):Play()
    task.wait(1.4)
    LSub.Text = "Ready! 💎"
    task.wait(0.3)
    -- Fade children first
    for _, ch in ipairs(LoadScreen:GetChildren()) do
        if ch:IsA("TextLabel") then
            TweenService:Create(ch, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
        elseif ch:IsA("Frame") then
            TweenService:Create(ch, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
        end
    end
    TweenService:Create(LoadScreen, TweenInfo.new(0.4, Enum.EasingStyle.Quad),
        {BackgroundTransparency = 1}):Play()
    task.wait(0.45)
    LoadScreen:Destroy()
end)

-- ════════════════════════════════════════════════════════════════
--  7.  NAVIGATION
--      Desktop → left sidebar   |   Mobile → bottom nav bar
-- ════════════════════════════════════════════════════════════════
local NAV = {
    {id="universal", label="🌐  Universal",  icon="🌐", short="Universal",  sub="No key required"},
}
if MainGame then
    table.insert(NAV, {id="maingame", label="🔐  "..MainGame.GAME_NAME, icon="🔐", short=MainGame.GAME_NAME:sub(1,10), sub="72h key from Discord"})
end
table.insert(NAV, {id="settings", label="⚙️  Settings", icon="⚙️", short="Settings", sub="Key & hub config"})

local tabBtns = {}

if isMobile then
    -- ── MOBILE: Bottom navigation bar ────────────────────────────
    local BottomNav = Instance.new("Frame")
    BottomNav.Name             = "BottomNav"
    BottomNav.Size             = UDim2.new(1, 0, 0, BOTTOM_H)
    BottomNav.Position         = UDim2.new(0, 0, 1, -BOTTOM_H)
    BottomNav.BackgroundColor3 = C.SIDEBAR
    BottomNav.BorderSizePixel  = 0
    BottomNav.ZIndex           = 10
    BottomNav.Parent           = Window

    -- Top divider line
    local NavDivider = Instance.new("Frame")
    NavDivider.Size             = UDim2.new(1, 0, 0, 1)
    NavDivider.BackgroundColor3 = C.ACCENT
    NavDivider.BackgroundTransparency = 0.6
    NavDivider.BorderSizePixel  = 0
    NavDivider.ZIndex           = 11
    NavDivider.Parent           = BottomNav

    local btnW = math.floor(WIN_W / #NAV)
    for i, tab in ipairs(NAV) do
        local btn = Instance.new("TextButton")
        btn.Name             = "Tab_"..tab.id
        btn.Size             = UDim2.new(0, btnW, 1, -1)
        btn.Position         = UDim2.new(0, (i-1)*btnW, 0, 1)
        btn.BackgroundColor3 = C.SIDEBAR
        btn.BorderSizePixel  = 0
        btn.Text             = ""
        btn.AutoButtonColor  = false
        btn.ZIndex           = 11
        btn.Parent           = BottomNav

        local ico = Instance.new("TextLabel")
        ico.Size             = UDim2.new(1, 0, 0, 22)
        ico.Position         = UDim2.new(0, 0, 0, 5)
        ico.BackgroundTransparency = 1
        ico.Text             = tab.icon
        ico.TextColor3       = C.SUBTEXT
        ico.Font             = FONT_SEMI
        ico.TextSize         = 16
        ico.ZIndex           = 12
        ico.Parent           = btn

        local lbl = Instance.new("TextLabel")
        lbl.Size             = UDim2.new(1, 0, 0, 14)
        lbl.Position         = UDim2.new(0, 0, 0, 28)
        lbl.BackgroundTransparency = 1
        lbl.Text             = tab.short
        lbl.TextColor3       = C.SUBTEXT
        lbl.Font             = FONT_SEMI
        lbl.TextSize         = 10
        lbl.ZIndex           = 12
        lbl.Parent           = btn

        -- Active indicator stripe
        local stripe = Instance.new("Frame")
        stripe.Name             = "Stripe"
        stripe.Size             = UDim2.new(0.6, 0, 0, 2)
        stripe.Position         = UDim2.new(0.2, 0, 0, 1)
        stripe.BackgroundColor3 = C.ACCENT
        stripe.BorderSizePixel  = 0
        stripe.BackgroundTransparency = 1  -- hidden until active
        stripe.ZIndex           = 12
        stripe.Parent           = btn
        Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 1)

        tabBtns[tab.id] = {btn=btn, lbl=lbl, ico=ico, stripe=stripe}
    end

else
    -- ── DESKTOP: Left sidebar ─────────────────────────────────────
    local Sidebar = Instance.new("Frame")
    Sidebar.Size             = UDim2.new(0, SIDEBAR_W, 1, 0)
    Sidebar.BackgroundColor3 = C.SIDEBAR
    Sidebar.BorderSizePixel  = 0
    Sidebar.Parent           = Window
    Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 12)

    local SBFill = Instance.new("Frame")
    SBFill.Size             = UDim2.new(0, 12, 1, 0)
    SBFill.Position         = UDim2.new(1, -12, 0, 0)
    SBFill.BackgroundColor3 = C.SIDEBAR
    SBFill.BorderSizePixel  = 0
    SBFill.Parent           = Sidebar

    local LogoLabel = Instance.new("TextLabel")
    LogoLabel.Size           = UDim2.new(1, -16, 0, 26)
    LogoLabel.Position       = UDim2.new(0, 10, 0, 16)
    LogoLabel.BackgroundTransparency = 1
    LogoLabel.Text           = "💎  EMERALD HUB"
    LogoLabel.TextColor3     = C.ACCENT
    LogoLabel.Font           = FONT
    LogoLabel.TextSize       = LOGO_TS
    LogoLabel.TextXAlignment = Enum.TextXAlignment.Left
    LogoLabel.Parent         = Sidebar

    local VerLabel = Instance.new("TextLabel")
    VerLabel.Size            = UDim2.new(1, -16, 0, 14)
    VerLabel.Position        = UDim2.new(0, 10, 0, 44)
    VerLabel.BackgroundTransparency = 1
    VerLabel.Text            = "v2.1  •  72hr Keyed"
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

    -- Close button (desktop only)
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
end

-- ════════════════════════════════════════════════════════════════
--  8.  CONTENT AREA + TOAST
-- ════════════════════════════════════════════════════════════════
local Content = Instance.new("Frame")
Content.Name             = "Content"
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.Parent           = Window

if isMobile then
    -- Full width, but leave BOTTOM_H for the nav bar
    Content.Size     = UDim2.new(1, 0, 1, -BOTTOM_H)
    Content.Position = UDim2.new(0, 0, 0, 0)
else
    -- Leave left SIDEBAR_W for sidebar
    Content.Size     = UDim2.new(1, -SIDEBAR_W, 1, 0)
    Content.Position = UDim2.new(0, SIDEBAR_W, 0, 0)
end

-- Mobile close button (top-right X) 
if isMobile then
    local MCloseBtn = Instance.new("TextButton")
    MCloseBtn.Size            = UDim2.new(0, 44, 0, 44)
    MCloseBtn.Position        = UDim2.new(1, -48, 0, 4)
    MCloseBtn.BackgroundColor3= Color3.fromRGB(22, 10, 10)
    MCloseBtn.BorderSizePixel = 0
    MCloseBtn.Text            = "✕"
    MCloseBtn.TextColor3      = C.DANGER
    MCloseBtn.Font            = FONT
    MCloseBtn.TextSize        = 18
    MCloseBtn.AutoButtonColor = false
    MCloseBtn.ZIndex          = 5
    MCloseBtn.Parent          = Content
    Instance.new("UICorner", MCloseBtn).CornerRadius = UDim.new(0, 10)
    MCloseBtn.MouseButton1Click:Connect(function()
        TweenService:Create(ScreenGui,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{}):Play()
        ScreenGui:Destroy()
    end)
end

-- Toast notification
local toastOffset = isMobile and -58 or -50
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
    TweenService:Create(Toast,TweenInfo.new(0.3,Enum.EasingStyle.Back),{Position=UDim2.new(0,16,1,toastOffset)}):Play()
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
    sf.ScrollBarThickness    = isMobile and 2 or 4
    sf.ScrollBarImageColor3  = C.ACCENT
    sf.CanvasSize            = UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    sf.Parent                = parent

    local layout = Instance.new("UIListLayout")
    layout.Padding   = UDim.new(0, isMobile and 10 or 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent    = sf

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, isMobile and 12 or 16)
    pad.PaddingRight  = UDim.new(0, isMobile and 12 or 16)
    pad.PaddingTop    = UDim.new(0, isMobile and 10 or 12)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.Parent        = sf

    return sf
end

local function makeCard(script, parent, locked)
    local card = Instance.new("Frame")
    card.Size             = UDim2.new(1, 0, 0, CARD_H)
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
    nameL.TextSize        = isMobile and 15 or 14
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
    descL.TextSize        = isMobile and 12 or 11
    descL.TextXAlignment  = Enum.TextXAlignment.Left
    descL.TextTruncate    = Enum.TextTruncate.AtEnd
    descL.Parent          = card

    -- Execute button
    local execBtn = Instance.new("TextButton")
    execBtn.Size            = UDim2.new(0, isMobile and 100 or 88, 0, BTN_H)
    execBtn.Position        = UDim2.new(0, 16, 1, -(BTN_H + 10))
    execBtn.BackgroundColor3= locked and Color3.fromRGB(36,28,6) or C.ACCENT
    execBtn.BorderSizePixel = 0
    execBtn.Text            = locked and "🔒 Locked" or "▶  Execute"
    execBtn.TextColor3      = locked and C.WARNING or Color3.fromRGB(255,255,255)
    execBtn.Font            = FONT_SEMI
    execBtn.TextSize        = BTN_TS
    execBtn.AutoButtonColor = false
    execBtn.Parent          = card
    Instance.new("UICorner", execBtn).CornerRadius = UDim.new(0, 7)

    if not isMobile then
        card.MouseEnter:Connect(function() card.BackgroundColor3 = C.CARDH end)
        card.MouseLeave:Connect(function() card.BackgroundColor3 = C.CARD  end)
    end

    if not locked then
        if not isMobile then
            execBtn.MouseEnter:Connect(function() TweenService:Create(execBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT2}):Play() end)
            execBtn.MouseLeave:Connect(function() TweenService:Create(execBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT}):Play() end)
        end
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

-- Page header (mobile only)
if isMobile then
    local PHeader = Instance.new("TextLabel")
    PHeader.Size             = UDim2.new(1, -60, 0, 40)
    PHeader.Position         = UDim2.new(0, 14, 0, 0)
    PHeader.BackgroundTransparency = 1
    PHeader.Text             = "🌐  Universal Scripts"
    PHeader.TextColor3       = C.ACCENT
    PHeader.Font             = FONT
    PHeader.TextSize         = 16
    PHeader.TextXAlignment   = Enum.TextXAlignment.Left
    PHeader.Parent           = PageUniversal
end

local uScroll = makeScroll(PageUniversal)
if isMobile then
    uScroll.Size     = UDim2.new(1, 0, 1, -40)
    uScroll.Position = UDim2.new(0, 0, 0, 40)
end

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
--  11.  PAGE: MAIN GAME
-- ════════════════════════════════════════════════════════════════
local keyUnlocked = false
local PageMainGame = nil

if MainGame then
local PageMainGame_ = Instance.new("Frame")
PageMainGame = PageMainGame_
local PageMainGame = PageMainGame_
PageMainGame.Size               = UDim2.new(1,0,1,0)
PageMainGame.BackgroundTransparency = 1
PageMainGame.Visible            = false
PageMainGame.Parent             = Pages

-- Mobile header
if isMobile then
    local MGH = Instance.new("TextLabel")
    MGH.Size             = UDim2.new(1, -60, 0, 40)
    MGH.Position         = UDim2.new(0, 14, 0, 0)
    MGH.BackgroundTransparency = 1
    MGH.Text             = "🔐  "..MainGame.GAME_NAME
    MGH.TextColor3       = C.ACCENT
    MGH.Font             = FONT
    MGH.TextSize         = 16
    MGH.TextXAlignment   = Enum.TextXAlignment.Left
    MGH.Parent           = PageMainGame
end

-- ── Key Gate ─────────────────────────────────────────────────────
local keyGateOffset = isMobile and 40 or 0
local KeyGate = Instance.new("Frame")
KeyGate.Size             = UDim2.new(1,0,1,-keyGateOffset)
KeyGate.Position         = UDim2.new(0,0,0,keyGateOffset)
KeyGate.BackgroundColor3 = C.BG
KeyGate.BorderSizePixel  = 0
KeyGate.ZIndex           = 10
KeyGate.Parent           = PageMainGame
Instance.new("UICorner", KeyGate).CornerRadius = UDim.new(0,12)

local cardW = isMobile and math.min(WIN_W - 40, 380) or 380
local KeyCard = Instance.new("Frame")
KeyCard.Size             = UDim2.new(0, cardW, 0, 270)
KeyCard.Position         = UDim2.new(0.5, -cardW/2, 0.5, -135)
KeyCard.BackgroundColor3 = C.CARD
KeyCard.BorderSizePixel  = 0
KeyCard.ZIndex           = 11
KeyCard.Parent           = KeyGate
Instance.new("UICorner", KeyCard).CornerRadius = UDim.new(0,12)

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
KTitle.TextSize          = isMobile and 14 or 16
KTitle.TextXAlignment    = Enum.TextXAlignment.Left
KTitle.TextWrapped       = true
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
KInput.TextSize          = isMobile and 12 or 13
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

local KBtn = Instance.new("TextButton")
KBtn.Size                = UDim2.new(1,-32,0,42)
KBtn.Position            = UDim2.new(0,16,0,182)
KBtn.BackgroundColor3    = C.ACCENT
KBtn.BorderSizePixel     = 0
KBtn.Text                = "Unlock  "..MainGame.GAME_NAME.."  Scripts"
KBtn.TextColor3          = Color3.fromRGB(255,255,255)
KBtn.Font                = FONT
KBtn.TextSize            = isMobile and 13 or 14
KBtn.AutoButtonColor     = false
KBtn.ZIndex              = 12
KBtn.Parent              = KeyCard
Instance.new("UICorner", KBtn).CornerRadius = UDim.new(0,8)
if not isMobile then
    KBtn.MouseEnter:Connect(function() TweenService:Create(KBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT2}):Play() end)
    KBtn.MouseLeave:Connect(function() TweenService:Create(KBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT}):Play() end)
end

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

local mgScroll = makeScroll(PageMainGame)
mgScroll.Visible = false
if isMobile then
    mgScroll.Size     = UDim2.new(1, 0, 1, -40)
    mgScroll.Position = UDim2.new(0, 0, 0, 40)
end

local mgCards = {}
for i, s in ipairs(MainGame.Scripts) do
    local card, execBtn = makeCard(s, mgScroll, true)
    card.LayoutOrder = i
    table.insert(mgCards, {script=s, card=card, execBtn=execBtn})
end

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
        if not isMobile then
            entry.execBtn.MouseEnter:Connect(function() TweenService:Create(entry.execBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT2}):Play() end)
            entry.execBtn.MouseLeave:Connect(function() TweenService:Create(entry.execBtn,TweenInfo.new(0.12),{BackgroundColor3=C.ACCENT}):Play() end)
        end
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
        for _ = 1, 3 do
            TweenService:Create(KInputFrame,TweenInfo.new(0.05),{Position=UDim2.new(0,22,0,100)}):Play() task.wait(0.05)
            TweenService:Create(KInputFrame,TweenInfo.new(0.05),{Position=UDim2.new(0,10,0,100)}):Play() task.wait(0.05)
        end
        TweenService:Create(KInputFrame,TweenInfo.new(0.08),{Position=UDim2.new(0,16,0,100)}):Play()
    end
end

KBtn.MouseButton1Click:Connect(function() tryKey(KInput.Text) end)
KInput.FocusLost:Connect(function(enter) if enter then tryKey(KInput.Text) end end)

task.spawn(function()
    local saved = KeySystem.Load()
    if saved then
        KInput.Text = saved
        KStatus.Text = "Found saved key — verifying…"
        task.wait(1)
        tryKey(saved)
    end
end)

end -- if MainGame

-- ════════════════════════════════════════════════════════════════
--  12.  PAGE: SETTINGS
-- ════════════════════════════════════════════════════════════════
local PageSettings = Instance.new("Frame")
PageSettings.Size               = UDim2.new(1,0,1,0)
PageSettings.BackgroundTransparency = 1
PageSettings.Visible            = false
PageSettings.Parent             = Pages

-- Mobile header
if isMobile then
    local SH = Instance.new("TextLabel")
    SH.Size             = UDim2.new(1, -60, 0, 40)
    SH.Position         = UDim2.new(0, 14, 0, 0)
    SH.BackgroundTransparency = 1
    SH.Text             = "⚙️  Settings"
    SH.TextColor3       = C.ACCENT
    SH.Font             = FONT
    SH.TextSize         = 16
    SH.TextXAlignment   = Enum.TextXAlignment.Left
    SH.Parent           = PageSettings
end

local settY0 = isMobile and 48 or 0

local function settRow(y, label, value, valueColor)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,-32,0,40)
    row.Position         = UDim2.new(0,16,0,settY0 + y)
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
    h.Position         = UDim2.new(0,16,0,settY0 + y)
    h.BackgroundTransparency = 1
    h.Text             = text
    h.TextColor3       = C.ACCENT
    h.Font             = FONT
    h.TextSize         = 12
    h.TextXAlignment   = Enum.TextXAlignment.Left
    h.Parent           = PageSettings
end

sectHeader(12,  "ℹ  HUB INFO")
settRow(36,  "Version",         "2.1")
settRow(84,  "Key Type",        "72-hour self-signing",  C.WARNING)
settRow(132, "Target Game",     MainGame and MainGame.GAME_NAME or "Not supported", MainGame and C.ACCENT or C.SUBTEXT)
settRow(180, "Keyless Scripts", tostring(#Universal.Scripts).." scripts",  C.SUCCESS)
settRow(228, "Keyed Scripts",   MainGame and tostring(#MainGame.Scripts).." scripts" or "N/A — unsupported game", MainGame and C.SUCCESS or C.SUBTEXT)

sectHeader(284, "🔑  KEY STATUS")
local keyValRow = settRow(308, "Current Key", keyUnlocked and "✔ Unlocked" or "🔒 Locked",
                           keyUnlocked and C.SUCCESS or C.DANGER)

local ClearBtn = Instance.new("TextButton")
ClearBtn.Size            = UDim2.new(1,-32,0,40)
ClearBtn.Position        = UDim2.new(0,16,0,settY0 + 356)
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
howTo.Position         = UDim2.new(0,16,0,settY0 + 434)
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
    settings  = PageSettings,
}
if MainGame and PageMainGame then allPages.maingame = PageMainGame end
local currentTab = "universal"

local function switchTab(id)
    currentTab = id
    for tid, page in pairs(allPages) do page.Visible = (tid == id) end

    if isMobile then
        for tid, t in pairs(tabBtns) do
            local active = (tid == id)
            t.ico.TextColor3    = active and C.ACCENT  or C.SUBTEXT
            t.lbl.TextColor3    = active and C.ACCENT  or C.SUBTEXT
            TweenService:Create(t.stripe, TweenInfo.new(0.15),
                {BackgroundTransparency = active and 0 or 1}):Play()
        end
    else
        for tid, t in pairs(tabBtns) do
            local active = (tid == id)
            TweenService:Create(t.btn, TweenInfo.new(0.15),
                {BackgroundColor3 = active and C.CARD or C.SIDEBAR}):Play()
            t.lbl.TextColor3 = active and C.TEXT   or C.SUBTEXT
            t.sub.TextColor3 = active and C.ACCENT or C.SUBTEXT
        end
    end

    if id == "settings" then
        keyValRow.Text       = keyUnlocked and "✔ Unlocked" or "🔒 Locked"
        keyValRow.TextColor3 = keyUnlocked and C.SUCCESS or C.DANGER
    end
end

for tabId, t in pairs(tabBtns) do
    t.btn.MouseButton1Click:Connect(function() switchTab(tabId) end)
end

-- ════════════════════════════════════════════════════════════════
--  14.  OPEN ANIMATION
-- ════════════════════════════════════════════════════════════════
switchTab("universal")

if isMobile then
    -- No expand animation on mobile — loading screen handles the reveal
    Window.Size = UDim2.new(0, WIN_W, 0, WIN_H)
else
    -- Expand from centre, hidden behind the loading screen
    Window.Size = UDim2.new(0, WIN_W, 0, 0)
    TweenService:Create(Window, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, WIN_W, 0, WIN_H)}):Play()
end

print("[EmeraldHub] Loaded v2.1 — PlaceId "..game.PlaceId..(MainGame and (" → "..MainGame.GAME_NAME.." scripts available.") or " → no keyed scripts for this game.")..(isMobile and " [Mobile layout]" or " [Desktop layout]"))
