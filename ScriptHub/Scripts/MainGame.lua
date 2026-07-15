--[[
    MainGame.lua
    Keyed scripts for a specific main game.
    Default example: Blox Fruits (Place ID 2753915549)
    
    HOW TO CHANGE THE TARGET GAME:
    1. Change GAME_NAME and GAME_PLACE_ID below.
    2. Replace or add entries in the Scripts table.
    
    HOW TO ADD YOUR OWN SCRIPTS:
    Copy one of the existing entries.
    Fields:
      name        = display name
      description = short one-liner
      category    = tag for search
      code        = Lua code string that gets executed
]]

local MainGame = {}

-- ════════════════════════════════════════════
--  CONFIGURATION
-- ════════════════════════════════════════════

-- Display name shown in the hub header
MainGame.GAME_NAME = "Blox Fruits"

-- Optional: warn the user if they load this outside the target game
MainGame.GAME_PLACE_ID = 2753915549

-- ════════════════════════════════════════════
--  SCRIPTS
-- ════════════════════════════════════════════

MainGame.Scripts = {

    -- ── AUTO FARM ────────────────────────────────────────────────────────
    {
        name        = "Auto Farm (Current Quest)",
        description = "Teleports to and kills enemies for your active quest.",
        category    = "Farm",
        code        = [[
-- Blox Fruits – Simple Auto Farm (Quest monsters)
local Players  = game:GetService("Players")
local RS       = game:GetService("RunService")
local lp       = Players.LocalPlayer
local char     = lp.Character or lp.CharacterAdded:Wait()
local hum      = char:WaitForChild("Humanoid")
local root     = char:WaitForChild("HumanoidRootPart")

local farming  = true
local tool     = char:FindFirstChildOfClass("Tool")

local function getNearest()
    local nearest, dist = nil, math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") then
            local h = obj:FindFirstChild("Humanoid")
            local r = obj:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 and h ~= hum then
                local d = (root.Position - r.Position).Magnitude
                if d < dist then
                    nearest, dist = obj, d
                end
            end
        end
    end
    return nearest
end

print("[Hub] Auto Farm ON — set farming = false to stop")
while farming and task.wait(0.1) do
    if hum.Health <= 0 then task.wait(2) char = lp.Character or lp.CharacterAdded:Wait() hum = char:WaitForChild("Humanoid") root = char:WaitForChild("HumanoidRootPart") end
    local target = getNearest()
    if target then
        local tr = target:FindFirstChild("HumanoidRootPart")
        if tr then
            root.CFrame = tr.CFrame + Vector3.new(0, 3, 4)
            -- Attack with equipped tool
            local t = char:FindFirstChildOfClass("Tool")
            if t and t:FindFirstChild("Handle") then
                firetouchinterest(t.Handle, tr, 0)
                task.wait(0.05)
                firetouchinterest(t.Handle, tr, 1)
            end
        end
    end
end
]],
    },

    {
        name        = "Auto Eat Fruit",
        description = "Instantly eats any Blox Fruit dropped in the world.",
        category    = "Farm",
        code        = [[
local lp = game:GetService("Players").LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")

local function eatFruit(obj)
    if obj.Name == "Fruit" or obj:FindFirstChild("PickUp") then
        local r = obj:FindFirstChild("Handle") or obj:FindFirstChildOfClass("Part")
        if r then
            root.CFrame = r.CFrame + Vector3.new(0, 2, 0)
            firetouchinterest(root, r, 0)
            task.wait(0.2)
            firetouchinterest(root, r, 1)
            print("[Hub] Ate fruit: " .. obj.Name)
        end
    end
end

workspace.DescendantAdded:Connect(function(obj)
    task.wait(0.5)
    eatFruit(obj)
end)

for _, obj in ipairs(workspace:GetDescendants()) do
    eatFruit(obj)
end
print("[Hub] Auto Eat Fruit ON")
]],
    },

    -- ── ESP ───────────────────────────────────────────────────────────────
    {
        name        = "Fruit ESP",
        description = "Shows all Devil Fruits on the map with highlights.",
        category    = "ESP",
        code        = [[
local function highlightFruits()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj.Name:find("Fruit") or obj.Name:find("fruit")) and obj:IsA("Model") then
            if not obj:FindFirstChildOfClass("Highlight") then
                local h = Instance.new("Highlight")
                h.FillColor        = Color3.fromRGB(255, 215, 0)
                h.OutlineColor     = Color3.fromRGB(255,255,255)
                h.FillTransparency = 0.3
                h.Parent           = obj
            end
        end
    end
end

highlightFruits()
workspace.DescendantAdded:Connect(function(obj)
    task.wait(0.2)
    highlightFruits()
end)
print("[Hub] Fruit ESP ON")
]],
    },

    {
        name        = "Boss ESP",
        description = "Highlights all boss NPCs with a red overlay.",
        category    = "ESP",
        code        = [[
local bossTags = {"Boss", "boss", "King", "Admiral", "Warlord", "Dragon"}

local function isBoss(model)
    for _, tag in ipairs(bossTags) do
        if model.Name:find(tag) then return true end
    end
    return false
end

local function addESP(model)
    if isBoss(model) and model:FindFirstChildOfClass("Humanoid") then
        if not model:FindFirstChildOfClass("Highlight") then
            local h = Instance.new("Highlight")
            h.FillColor = Color3.fromRGB(220,30,30)
            h.OutlineColor = Color3.fromRGB(255,255,255)
            h.FillTransparency = 0.4
            h.Parent = model
        end
    end
end

for _, v in ipairs(workspace:GetDescendants()) do addESP(v) end
workspace.DescendantAdded:Connect(addESP)
print("[Hub] Boss ESP ON")
]],
    },

    -- ── TELEPORT ─────────────────────────────────────────────────────────
    {
        name        = "Teleport to Sea 1",
        description = "Teleports your character to the Sea 1 starter island.",
        category    = "Teleport",
        code        = [[
local lp = game:GetService("Players").LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
-- Approximate Sea 1 spawn in Blox Fruits
root.CFrame = CFrame.new(-1270, 40, 1760)
print("[Hub] Teleported to Sea 1")
]],
    },

    {
        name        = "Teleport to Café",
        description = "Teleports to the in-game café (Sea 1 hub).",
        category    = "Teleport",
        code        = [[
local lp = game:GetService("Players").LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
root.CFrame = CFrame.new(-1381, 40, 1827)
print("[Hub] Teleported to Café")
]],
    },

    -- ── STATS ─────────────────────────────────────────────────────────────
    {
        name        = "Auto Stats (Melee Build)",
        description = "Puts stat points into Melee automatically on level-up.",
        category    = "Stats",
        code        = [[
-- Fires the remote that distributes stat points (Melee build)
local lp   = game:GetService("Players").LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()

local statRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Stat", true)
                or game:GetService("ReplicatedStorage"):FindFirstChild("AddStat", true)

if statRemote then
    -- Put all available points into Melee
    local data = lp:WaitForChild("Data", 10)
    if data then
        local points = data:FindFirstChild("StatPoints") or data:FindFirstChild("Points")
        if points then
            for i = 1, points.Value do
                statRemote:FireServer("Melee")
            end
            print("[Hub] Dumped "..points.Value.." points into Melee")
        end
    end
else
    print("[Hub] Stat remote not found – may need to update for current patch")
end
]],
    },

    -- ── MISC ──────────────────────────────────────────────────────────────
    {
        name        = "Auto Accept Trade",
        description = "Automatically accepts all incoming trade requests.",
        category    = "Misc",
        code        = [[
local RS = game:GetService("ReplicatedStorage")
RS.DescendantAdded:Connect(function(obj)
    if obj.Name == "TradeRequest" or obj.Name == "RequestTrade" then
        task.wait(0.5)
        local remote = RS:FindFirstChild("AcceptTrade", true)
        if remote then remote:FireServer() end
    end
end)
print("[Hub] Auto Accept Trade ON")
]],
    },

    {
        name        = "Kill Aura (Sword)",
        description = "Swings your equipped sword at all nearby enemies.",
        category    = "Combat",
        code        = [[
local lp   = game:GetService("Players").LocalPlayer
local RS   = game:GetService("RunService")
local char = lp.Character or lp.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local hum  = char:WaitForChild("Humanoid")
local running = true

print("[Hub] Kill Aura ON (set running=false to stop)")
RS.Heartbeat:Connect(function()
    if not running then return end
    char = lp.Character
    if not char then return end
    root = char:FindFirstChild("HumanoidRootPart")
    hum  = char:FindFirstChildOfClass("Humanoid")
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or not root then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= char then
            local eh = obj:FindFirstChildOfClass("Humanoid")
            local er = obj:FindFirstChild("HumanoidRootPart")
            if eh and er and eh.Health > 0 then
                local dist = (root.Position - er.Position).Magnitude
                if dist < 10 then
                    local handle = tool:FindFirstChild("Handle")
                    if handle then
                        firetouchinterest(handle, er, 0)
                        task.wait(0.05)
                        firetouchinterest(handle, er, 1)
                    end
                end
            end
        end
    end
end)
]],
    },
}

return MainGame
