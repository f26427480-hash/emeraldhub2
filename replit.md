# EmeraldHub Discord Bot

A Discord bot that generates self-signing 72-hour keys for the EmeraldHub Roblox script hub. No database or web server required — keys are signed with a shared secret and verified locally in Lua.

## How to Run

The workflow **EmeraldHub Discord Bot** runs the bot automatically:
```
cd EmeraldBot && node bot.js
```

## Required Secrets

Set these in Replit Secrets (already configured):

| Secret | Description |
|--------|-------------|
| `DISCORD_TOKEN` | Bot token from the Discord Developer Portal |
| `HUB_SECRET` | Shared secret — must exactly match `HUB_SECRET` in `Main.lua` |

## Optional Environment Variables

Set these as Replit Secrets if needed:

| Variable | Description |
|----------|-------------|
| `KEYGEN_CHANNEL_ID` | Restrict `/getkey` to a specific Discord channel |
| `REQUIRED_ROLE_ID` | Require a specific role before users can get a key |
| `GUILD_ID` | Your server ID — makes slash commands register instantly |

## Bot Commands

| Command | Description |
|---------|-------------|
| `/getkey` | DMs the user a fresh 72-hour key |
| `/keyinfo <key>` | Shows how long a key is still valid |
| `/hubinfo` | Shows EmeraldHub info and instructions |

## Revoking All Keys

Change `HUB_SECRET` in Replit Secrets **and** in `Main.lua` to a new random value. All existing keys become invalid immediately.

## User Preferences
