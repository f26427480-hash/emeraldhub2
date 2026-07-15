--[[
    KeySystem.lua
    Handles key validation, HWID binding, and key storage.
    
    HOW TO SET YOUR VALID KEYS:
    1. Edit the VALID_KEYS table below with your own keys.
    2. You can generate keys any way you like (Discord bot, website, etc.)
    
    KEY FILE: Keys are saved locally so users don't need to re-enter them.
    Change KEY_FILE if you want a different save path.
]]

local KeySystem = {}

-- ════════════════════════════════════════════
--  CONFIGURATION  ─ edit this section only
-- ════════════════════════════════════════════

-- Add as many keys as you want here
KeySystem.VALID_KEYS = {
    "MYHUB-ALPHA-1234",
    "MYHUB-BETA-5678",
    "MYHUB-GAMMA-9999",
    "MYHUB-DELTA-ABCD",
}

-- File name stored in executor workspace (writefile/readfile)
KeySystem.KEY_FILE = "ScriptHub_Key.txt"

-- Key expiry in seconds (set to nil for no expiry)
-- Example: 86400 = 24 hours, 604800 = 7 days
KeySystem.KEY_EXPIRY = nil

-- Bind key to HWID (prevents key sharing)
-- When true, a key can only be used on the machine it was first entered on.
KeySystem.HWID_BIND = true

-- ════════════════════════════════════════════
--  INTERNAL LOGIC  ─ do not edit below
-- ════════════════════════════════════════════

local function getHWID()
    -- Executors expose RbxAnalyticsService or a unique device fingerprint.
    -- Fall back to a derived string if unavailable.
    local ok, id = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and id and id ~= "" then return id end
    -- Fallback: combine place + player userId as a lightweight fingerprint
    local player = game:GetService("Players").LocalPlayer
    return tostring(player and player.UserId or 0) .. "_" .. tostring(game.PlaceId)
end

local function readSaved()
    local ok, data = pcall(readfile, KeySystem.KEY_FILE)
    if ok and data then
        local savedKey, savedHwid, savedTime = data:match("^(.+)|(.+)|(%d+)$")
        if savedKey then
            return savedKey, savedHwid, tonumber(savedTime)
        end
    end
    return nil, nil, nil
end

local function saveKey(key)
    local hwid = getHWID()
    local data = key .. "|" .. hwid .. "|" .. tostring(os.time())
    pcall(writefile, KeySystem.KEY_FILE, data)
end

-- Returns true/false, and a reason string on failure
function KeySystem.Validate(inputKey)
    if not inputKey or inputKey == "" then
        return false, "No key entered."
    end

    -- Normalise input
    local key = inputKey:gsub("%s+", ""):upper()

    -- Check against valid keys list (case-insensitive stored normalised)
    local valid = false
    for _, v in ipairs(KeySystem.VALID_KEYS) do
        if v:upper() == key then
            valid = true
            break
        end
    end

    if not valid then
        return false, "Invalid key. Please check your key and try again."
    end

    -- HWID check
    if KeySystem.HWID_BIND then
        local savedKey, savedHwid, _ = readSaved()
        if savedKey and savedKey:upper() == key then
            local currentHwid = getHWID()
            if savedHwid ~= currentHwid then
                return false, "Key is bound to a different device."
            end
        end
    end

    return true, "Key accepted!"
end

-- Try to auto-load a saved key; returns key string or nil
function KeySystem.LoadSaved()
    local savedKey, savedHwid, savedTime = readSaved()
    if not savedKey then return nil end

    -- Expiry check
    if KeySystem.KEY_EXPIRY and savedTime then
        if os.time() - savedTime > KeySystem.KEY_EXPIRY then
            pcall(delfile, KeySystem.KEY_FILE)
            return nil
        end
    end

    -- HWID check
    if KeySystem.HWID_BIND and savedHwid then
        if savedHwid ~= getHWID() then
            return nil
        end
    end

    -- Still valid
    return savedKey
end

function KeySystem.Save(key)
    saveKey(key)
end

function KeySystem.Clear()
    pcall(delfile, KeySystem.KEY_FILE)
end

return KeySystem
