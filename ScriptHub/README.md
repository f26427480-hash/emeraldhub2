# ScriptHub — Roblox Script Hub

A self-contained Roblox script hub with:
- **Universal tab** — keyless scripts that work in any game
- **Main Game tab** — keyed scripts (default: Blox Fruits)
- **Key System** — HWID-bound, saved locally so you only enter it once
- **Search bar** — filter scripts by name, category, or description
- **Inject system** — all scripts are embedded in the code itself

---

## Files

```
ScriptHub/
├── Main.lua                  ← EXECUTE THIS in your exploit
├── Modules/
│   └── KeySystem.lua         ← Standalone key system reference
└── Scripts/
    ├── Universal.lua         ← Standalone universal scripts reference
    └── MainGame.lua          ← Standalone main game scripts reference
```

> **Note:** `Main.lua` is fully self-contained — all modules and scripts are
> inlined inside it. The `Modules/` and `Scripts/` files are for reference and
> easy copy-paste when adding new scripts.

---

## How to Use

1. Open your executor (Synapse X, KRNL, Fluxus, etc.)
2. Attach it to Roblox
3. Open/paste **`Main.lua`** and execute it
4. The hub GUI appears — drag it anywhere

### Universal Tab (no key needed)
Click **▶ Execute** on any script. A green toast confirms success.

### Main Game Tab (key required)
1. Click the **Main Game** tab
2. Enter your key (e.g. `MYHUB-ALPHA-1234`)
3. Press **Enter** or click **Unlock Scripts**
4. Once unlocked, click **▶ Execute** on any script
5. Your key is saved locally — you won't need to re-enter it next time

---

## Customising Keys

Open `Main.lua` and find the `VALID_KEYS` table near the top:

```lua
M.VALID_KEYS = {
    "MYHUB-ALPHA-1234",
    "MYHUB-BETA-5678",
    "MYHUB-GAMMA-9999",
    "MYHUB-DELTA-ABCD",
}
```

Add, remove, or change any key. Anyone with a key in this list can unlock
the Main Game tab.

---

## Adding Scripts

### To Universal (keyless)

Find `Universal.Scripts` in `Main.lua` and add a new entry:

```lua
{
    name        = "My Script Name",
    description = "One-line description of what it does.",
    category    = "Movement",  -- used for search filtering
    code        = [[
        -- Your Lua code here
        print("Hello from my script!")
    ]],
},
```

### To Main Game (keyed)

Find `MainGame.Scripts` in `Main.lua` and add the same way:

```lua
{
    name        = "My Keyed Script",
    description = "Only visible after key is entered.",
    category    = "Combat",
    code        = [[
        -- Your game-specific Lua code here
    ]],
},
```

---

## Changing the Target Game

Find `MainGame.GAME_NAME` and `MainGame.GAME_PLACE_ID` in `Main.lua`:

```lua
MainGame.GAME_NAME     = "Blox Fruits"
MainGame.GAME_PLACE_ID = 2753915549
```

Change these to match your target game.

---

## Included Scripts

### Universal (12 scripts)
| Script | Category |
|--------|----------|
| Infinite Jump | Movement |
| WalkSpeed Changer | Movement |
| High Jump | Movement |
| Fly Script (hold Q) | Movement |
| Noclip (toggle N) | Movement |
| Player ESP | Visual |
| Fullbright | Visual |
| FOV Changer | Visual |
| Anti-AFK | Utility |
| Rejoin | Utility |
| Copy Server Link | Utility |
| Hide Character | Utility |

### Main Game — Blox Fruits (8 scripts, keyed)
| Script | Category |
|--------|----------|
| Auto Farm (Quest) | Farm |
| Auto Eat Fruit | Farm |
| Fruit ESP | ESP |
| Boss ESP | ESP |
| TP Sea 1 | Teleport |
| Kill Aura (Sword) | Combat |
| Auto Stats Melee | Stats |
| Auto Accept Trade | Misc |

---

## Key System Details

- Keys are saved to `ScriptHub_Key.txt` in your executor's workspace folder
- HWID binding is **on by default** — a key only works on the machine it was first used on
- To turn off HWID binding: find `M.HWID_BIND = true` and set it to `false`
- To add expiry: find `M.KEY_EXPIRY = nil` and set seconds (e.g. `86400` = 24 hours)
- Keys are normalised to uppercase — `myhub-alpha-1234` works the same as `MYHUB-ALPHA-1234`
