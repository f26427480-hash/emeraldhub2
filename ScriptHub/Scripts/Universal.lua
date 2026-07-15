--[[
    Universal.lua
    Keyless scripts that work across all/most Roblox games.
    
    HOW TO ADD YOUR OWN SCRIPTS:
    Copy one of the existing entries and paste it into the table.
    Fields:
      name        = display name shown in the hub
      description = short one-line description shown under the name
      category    = tag used for the search filter
      code        = the actual Lua code that gets executed (loadstring)
]]

local Universal = {}

Universal.Scripts = {

    -- ── MOVEMENT ─────────────────────────────────────────────────────────
    {
        name        = "Infinite Jump",
        description = "Press Space in mid-air to jump again.",
        category    = "Movement",
        code        = [[
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local jumping = false

UIS.JumpRequest:Connect(function()
    if not lp.Character then return end
    local hr = lp.Character:FindFirstChild("HumanoidRootPart")
    local hum = lp.Character:FindFirstChildOfClass("Humanoid")
    if hr and hum and hum:GetState() ~= Enum.HumanoidStateType.Dead then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)
print("[Hub] Infinite Jump enabled")
]],
    },

    {
        name        = "WalkSpeed Changer",
        description = "Sets your WalkSpeed to 50 (editable).",
        category    = "Movement",
        code        = [[
local speed = 50  -- change this value
local lp = game:GetService("Players").LocalPlayer
local function setSpeed()
    local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = speed end
end
setSpeed()
lp.CharacterAdded:Connect(function(c)
    c:WaitForChild("Humanoid").WalkSpeed = speed
end)
print("[Hub] WalkSpeed set to "..speed)
]],
    },

    {
        name        = "High Jump",
        description = "Sets JumpPower to 120 so you jump very high.",
        category    = "Movement",
        code        = [[
local power = 120  -- change this value
local lp = game:GetService("Players").LocalPlayer
local function setJump()
    local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.JumpPower = power end
end
setJump()
lp.CharacterAdded:Connect(function(c)
    c:WaitForChild("Humanoid").JumpPower = power
end)
print("[Hub] JumpPower set to "..power)
]],
    },

    {
        name        = "Fly Script",
        description = "Hold Q to fly. Uses BodyVelocity.",
        category    = "Movement",
        code        = [[
local UIS = game:GetService("UserInputService")
local RS  = game:GetService("RunService")
local lp  = game:GetService("Players").LocalPlayer
local cam = workspace.CurrentCamera
local flying = false
local bv, bg

local function startFly()
    local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    bv = Instance.new("BodyVelocity", root)
    bv.MaxForce = Vector3.new(1e5,1e5,1e5)
    bv.Velocity  = Vector3.new(0,0,0)
    bg = Instance.new("BodyGyro", root)
    bg.MaxTorque = Vector3.new(1e5,1e5,1e5)
    bg.P = 1e4
    flying = true
    print("[Hub] Fly ON — hold Q")
end
local function stopFly()
    if bv then bv:Destroy() end
    if bg then bg:Destroy() end
    flying = false
    print("[Hub] Fly OFF")
end

UIS.InputBegan:Connect(function(i,g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.Q then startFly() end
end)
UIS.InputEnded:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.Q then stopFly() end
end)

RS.RenderStepped:Connect(function()
    if not flying then return end
    local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not root or not bv then return end
    local speed = 60
    local dir = cam.CFrame.LookVector
    if UIS:IsKeyDown(Enum.KeyCode.W) then bv.Velocity = dir*speed
    elseif UIS:IsKeyDown(Enum.KeyCode.S) then bv.Velocity = -dir*speed
    elseif UIS:IsKeyDown(Enum.KeyCode.A) then bv.Velocity = -cam.CFrame.RightVector*speed
    elseif UIS:IsKeyDown(Enum.KeyCode.D) then bv.Velocity = cam.CFrame.RightVector*speed
    elseif UIS:IsKeyDown(Enum.KeyCode.Space) then bv.Velocity = Vector3.new(0,speed,0)
    elseif UIS:IsKeyDown(Enum.KeyCode.LeftControl) then bv.Velocity = Vector3.new(0,-speed,0)
    else bv.Velocity = Vector3.new(0,0,0) end
    bg.CFrame = cam.CFrame
end)
]],
    },

    {
        name        = "Noclip",
        description = "Toggle noclip with N key. Walk through walls.",
        category    = "Movement",
        code        = [[
local UIS = game:GetService("UserInputService")
local RS  = game:GetService("RunService")
local lp  = game:GetService("Players").LocalPlayer
local noclip = false

UIS.InputBegan:Connect(function(i,g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.N then
        noclip = not noclip
        print("[Hub] Noclip "..(noclip and "ON" or "OFF"))
    end
end)

RS.Stepped:Connect(function()
    if noclip and lp.Character then
        for _, p in ipairs(lp.Character:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
            end
        end
    end
end)
]],
    },

    -- ── VISUAL ───────────────────────────────────────────────────────────
    {
        name        = "Player ESP",
        description = "Draws boxes/names above all players.",
        category    = "Visual",
        code        = [[
local Players  = game:GetService("Players")
local RS       = game:GetService("RunService")
local lp       = Players.LocalPlayer
local cam      = workspace.CurrentCamera
local highlight_store = {}

local function makeHighlight(char)
    local h = Instance.new("Highlight")
    h.FillColor        = Color3.fromRGB(255,50,50)
    h.OutlineColor     = Color3.fromRGB(255,255,255)
    h.FillTransparency = 0.5
    h.OutlineTransparency = 0
    h.Parent = char
    return h
end

local function addPlayer(p)
    if p == lp then return end
    local function onChar(char)
        if highlight_store[p] then highlight_store[p]:Destroy() end
        highlight_store[p] = makeHighlight(char)
    end
    if p.Character then onChar(p.Character) end
    p.CharacterAdded:Connect(onChar)
    p.CharacterRemoving:Connect(function()
        if highlight_store[p] then highlight_store[p]:Destroy() end
        highlight_store[p] = nil
    end)
end

for _, p in ipairs(Players:GetPlayers()) do addPlayer(p) end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(p)
    if highlight_store[p] then highlight_store[p]:Destroy() end
    highlight_store[p] = nil
end)
print("[Hub] Player ESP ON")
]],
    },

    {
        name        = "Fullbright",
        description = "Sets ambient lighting so the map is always bright.",
        category    = "Visual",
        code        = [[
local Lighting = game:GetService("Lighting")
Lighting.Brightness           = 2
Lighting.ClockTime            = 14
Lighting.FogEnd               = 1e6
Lighting.GlobalShadows        = false
Lighting.Ambient              = Color3.fromRGB(178,178,178)
Lighting.OutdoorAmbient       = Color3.fromRGB(178,178,178)
print("[Hub] Fullbright ON")
]],
    },

    {
        name        = "FOV Changer",
        description = "Sets camera FOV to 90 (editable).",
        category    = "Visual",
        code        = [[
local fov = 90  -- change this value
workspace.CurrentCamera.FieldOfView = fov
print("[Hub] FOV set to "..fov)
]],
    },

    -- ── UTILITY ──────────────────────────────────────────────────────────
    {
        name        = "Anti-AFK",
        description = "Prevents the idle kick by moving the virtual thumbstick.",
        category    = "Utility",
        code        = [[
local VirtualUser = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)
print("[Hub] Anti-AFK ON")
]],
    },

    {
        name        = "Rejoin",
        description = "Instantly rejoins the current game.",
        category    = "Utility",
        code        = [[
local TeleportService = game:GetService("TeleportService")
TeleportService:Teleport(game.PlaceId, game:GetService("Players").LocalPlayer)
]],
    },

    {
        name        = "Copy Join Link",
        description = "Copies a join link for this server to clipboard.",
        category    = "Utility",
        code        = [[
local id  = game.JobId
local pid = game.PlaceId
local link = "roblox://experiences/start?placeId="..pid.."&gameInstanceId="..id
setclipboard(link)
print("[Hub] Copied: "..link)
]],
    },

    {
        name        = "Hide Local Player",
        description = "Makes your own character invisible to yourself.",
        category    = "Utility",
        code        = [[
local lp = game:GetService("Players").LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
for _, p in ipairs(char:GetDescendants()) do
    if p:IsA("BasePart") or p:IsA("Decal") then
        p.Transparency = 1
    end
end
print("[Hub] Local character hidden")
]],
    },

    {
        name        = "Chat Spam (Custom)",
        description = "Sends a message in chat every 3 seconds.",
        category    = "Utility",
        code        = [[
local msg = "Hello from ScriptHub!"  -- change this message
local Players = game:GetService("Players")
task.spawn(function()
    while task.wait(3) do
        Players.LocalPlayer:Chat(msg)
    end
end)
print("[Hub] Chat spam started")
]],
    },
}

return Universal
