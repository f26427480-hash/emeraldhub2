# GameLibrary/games.json — Format Guide

Edit `games.json` to add, remove, or update games. Push to GitHub and the hub picks up changes automatically next time someone runs it.

---

## Add a game

Paste a new object into the array:

```json
{
  "name": "Game Name Here",
  "placeId": 123456789,
  "scripts": [
    {
      "name": "⭐  Script Name",
      "description": "Short description shown on the card.",
      "category": "Featured",
      "code": "loadstring(game:HttpGet(\"https://your-script-url-here\"))()"
    }
  ]
}
```

### Fields

| Field | Required | What it does |
|---|---|---|
| `name` | ✅ | Game name shown in the hub nav and tab |
| `placeId` | ✅ | Roblox PlaceId — hub auto-detects this game when matched |
| `scripts` | ✅ | Array of script cards shown inside the game tab |
| `scripts[].name` | ✅ | Card title (use ⭐ prefix for featured) |
| `scripts[].description` | ✅ | Short description shown under the name |
| `scripts[].category` | ✅ | Badge label, e.g. `"Featured"`, `"ESP"`, `"Farm"` |
| `scripts[].code` | ✅ | Lua code that runs when the user clicks Execute |

---

## Multiple scripts per game

```json
{
  "name": "Murder Mystery 2",
  "placeId": 142823291,
  "scripts": [
    {
      "name": "⭐  MM2 ESP",
      "description": "Highlights players and roles.",
      "category": "ESP",
      "code": "loadstring(game:HttpGet(\"https://example.com/esp.lua\"))()"
    },
    {
      "name": "⭐  MM2 Gun Mods",
      "description": "Speed and damage mods.",
      "category": "Combat",
      "code": "loadstring(game:HttpGet(\"https://example.com/gun.lua\"))()"
    }
  ]
}
```

---

## Find a PlaceId

Open the game on Roblox. The URL looks like:
```
https://www.roblox.com/games/142823291/Murder-Mystery-2
                              ^^^^^^^^^
                              This is the PlaceId
```

---

## Remove a game

Delete its entire `{ ... }` block from the array. Make sure commas between entries are correct.

---

## Full example (two games)

```json
[
  {
    "name": "Murder Mystery 2",
    "placeId": 142823291,
    "scripts": [
      {
        "name": "⭐  MM2 Script",
        "description": "ESP, role reveal, gun mods & more.",
        "category": "Featured",
        "code": "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/Joystickplays/psychic-octo-invention/main/yarhm.lua\", false))()"
      }
    ]
  },
  {
    "name": "Steal a Brainrot",
    "placeId": 109983668079237,
    "scripts": [
      {
        "name": "⭐  Steal a Brainrot",
        "description": "Auto steal, speed boost & more.",
        "category": "Featured",
        "code": "loadstring(game:HttpGet(\"https://paste.rs/RJhsl\"))()"
      }
    ]
  }
]
```
