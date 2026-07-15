# EmeraldHub Discord Bot — Setup Guide

This bot lets users run `/getkey` in your Discord server and receive a **72-hour key** via DM.  
Keys are **self-signing** — no database or web server needed. The expiry is baked into the key and verified locally by the Lua hub.

---

## 1 — Create the Discord Bot

1. Go to [discord.com/developers/applications](https://discord.com/developers/applications)
2. Click **New Application** → name it `EmeraldHub`
3. Go to **Bot** → click **Add Bot**
4. Under **Token** click **Reset Token** and copy it — you'll need it in a moment
5. Under **Privileged Gateway Intents** enable **Server Members Intent** (only needed if you use `REQUIRED_ROLE_ID`)
6. Go to **OAuth2 → URL Generator**
   - Scopes: `bot`, `applications.commands`
   - Bot Permissions: `Send Messages`, `Read Messages/View Channels`
7. Copy the generated URL, open it in your browser, and invite the bot to your server

---

## 2 — Configure the Bot

```bash
cd EmeraldBot
cp .env.example .env
```

Open `.env` and fill in:

```env
DISCORD_TOKEN=your_bot_token_here

# IMPORTANT: change this to a long random string
# Must EXACTLY match HUB_SECRET in ScriptHub/Main.lua
HUB_SECRET=CHANGE_THIS_TO_YOUR_OWN_SECRET

# Optional: only allow /getkey in a specific channel
KEYGEN_CHANNEL_ID=123456789012345678

# Optional: require users to have a specific role
REQUIRED_ROLE_ID=123456789012345678

# Optional: your server ID (makes slash commands register instantly)
GUILD_ID=123456789012345678
```

---

## 3 — Match the Secret in Main.lua

Open `ScriptHub/Main.lua` and find this line near the top:

```lua
local HUB_SECRET = "CHANGE_THIS_TO_YOUR_OWN_SECRET"
```

Set it to **exactly the same value** as `HUB_SECRET` in your `.env`.  
This is the only thing linking the bot's keys to the hub — keep it private.

---

## 4 — Install & Run

```bash
cd EmeraldBot
npm install
node bot.js
```

You should see:
```
[EmeraldBot] Logged in as EmeraldHub#1234
[EmeraldBot] Slash commands registered to guild 12345...
```

---

## 5 — Test It

1. Go to your Discord server
2. Type `/getkey` — check your DMs for the key
3. Open EmeraldHub in Roblox → Main Game tab → paste the key → click **Unlock**

You can also run `/keyinfo` with any key to see how much time is left on it.

---

## Available Commands

| Command | Description |
|---------|-------------|
| `/getkey` | DMs you a fresh 72-hour key |
| `/keyinfo <key>` | Shows how long the key is still valid |
| `/hubinfo` | Shows EmeraldHub info and instructions |

---

## How Keys Work (Technical)

No web server or database is involved. Here's the flow:

```
1. User runs /getkey in Discord
2. Bot calculates:  expiry = now + 72 hours  (Unix timestamp)
3. Bot encodes:     expB36 = expiry.toString(36).toUpperCase()
4. Bot signs:       hash   = hubHash(expB36 + HUB_SECRET)
5. Bot builds key:  EMERALD-{expB36}-{hash}   ← sent to user via DM

6. User pastes key into EmeraldHub
7. Hub parses:      expB36, hash = key.match(...)
8. Hub re-signs:    expectedHash = hubHash(expB36 + HUB_SECRET)
9. Hub checks:      hash == expectedHash  (forgery check)
10. Hub checks:     os.time() < expiry    (expiry check)
11. ✔ Unlocked — no HTTP call needed
```

Because the expiry is **encoded inside the key** and **signed with the secret**, keys:
- Cannot be forged without knowing `HUB_SECRET`
- Automatically expire after 72 hours — no revocation system needed
- Work offline — zero HTTP calls from the Lua side

---

## Keeping the Bot Running

For long-term hosting use **PM2**:

```bash
npm install -g pm2
pm2 start bot.js --name emerald-bot
pm2 save
pm2 startup   # auto-start on reboot
```

Or host on a VPS / free service like Railway, Render, or Fly.io.

---

## Changing Key Duration

Open `bot.js` and find:

```js
const KEY_DURATION_SECS = 72 * 60 * 60; // 72 hours
```

Change `72` to however many hours you want.  
The Lua hub reads the expiry from the key itself, so no changes needed there.

---

## Revoking All Keys (Emergency)

Change `HUB_SECRET` in both `.env` **and** `Main.lua` to a new random value.  
All existing keys immediately become invalid because their signatures no longer match.
