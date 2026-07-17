/**
 * EmeraldHub Discord Bot
 * Generates self-signing 72-hour keys for the EmeraldHub Roblox script hub.
 * One key per user per 72 hours — cooldown is enforced server-side.
 */

require("dotenv").config();
const fs = require("fs");
const { Client, GatewayIntentBits, SlashCommandBuilder, REST, Routes, EmbedBuilder } = require("discord.js");

// ─── CONFIG (read from .env) ──────────────────────────────────────────────────
const TOKEN             = process.env.DISCORD_TOKEN;
const HUB_SECRET        = process.env.HUB_SECRET        || "CHANGE_THIS_TO_YOUR_OWN_SECRET";
const KEYGEN_CHANNEL_ID = process.env.KEYGEN_CHANNEL_ID || null;
const REQUIRED_ROLE_ID  = process.env.REQUIRED_ROLE_ID  || null;
const GUILD_ID          = process.env.GUILD_ID          || null;
const KEY_DURATION_SECS = 72 * 60 * 60; // 72 hours

// Cooldown storage — persists across bot restarts
const COOLDOWNS_FILE = "./cooldowns.json";

if (!TOKEN || TOKEN === "your_bot_token_here") {
    console.error("[EmeraldBot] ERROR: Set DISCORD_TOKEN in your .env file.");
    process.exit(1);
}
if (HUB_SECRET === "CHANGE_THIS_TO_YOUR_OWN_SECRET") {
    console.warn("[EmeraldBot] WARNING: HUB_SECRET is still the default. Change it in .env and update Main.lua.");
}

// ─── COOLDOWN STORAGE ─────────────────────────────────────────────────────────

/** Load the cooldown map from disk. Returns { userId: issuedAtUnixSecs } */
function loadCooldowns() {
    try {
        return JSON.parse(fs.readFileSync(COOLDOWNS_FILE, "utf8"));
    } catch {
        return {};
    }
}

/** Persist the cooldown map to disk. */
function saveCooldowns(map) {
    fs.writeFileSync(COOLDOWNS_FILE, JSON.stringify(map, null, 2));
}

/**
 * Check whether a user is still within their 72-hour cooldown.
 * Returns { onCooldown: bool, secondsLeft: number }
 */
function checkCooldown(userId) {
    const map = loadCooldowns();
    const issuedAt = map[userId];
    if (!issuedAt) return { onCooldown: false, secondsLeft: 0 };
    const secondsLeft = issuedAt + KEY_DURATION_SECS - Math.floor(Date.now() / 1000);
    if (secondsLeft <= 0) return { onCooldown: false, secondsLeft: 0 };
    return { onCooldown: true, secondsLeft };
}

/** Record that a user just received a key. */
function recordCooldown(userId) {
    const map = loadCooldowns();
    map[userId] = Math.floor(Date.now() / 1000);
    saveCooldowns(map);
}

// ─── KEY GENERATION ───────────────────────────────────────────────────────────

/**
 * Simple polynomial hash that produces the same output as the Lua version
 * in Main.lua. Uses modulo 1_000_000_007 to stay within JS safe-integer range.
 * @param {string} s
 * @returns {string} zero-padded 7-digit decimal string
 */
function hubHash(s) {
    const MOD = 1_000_000_007n;
    let h = 0n;
    for (let i = 0; i < s.length; i++) {
        h = (h * 31n + BigInt(s.charCodeAt(i))) % MOD;
    }
    // Clamp to exactly 7 digits — MOD can produce up to 10 digits
    // which breaks the EMERALD-...-\d{7} regex on both sides.
    return (h % 10_000_000n).toString().padStart(7, "0");
}

/**
 * Generate a self-signing EmeraldHub key valid for KEY_DURATION_SECS seconds.
 * Format: EMERALD-{BASE36_EXPIRY_UPPER}-{7DIGIT_HASH}
 */
function generateKey() {
    const expiry  = Math.floor(Date.now() / 1000) + KEY_DURATION_SECS;
    const expB36  = expiry.toString(36).toUpperCase();
    const hash    = hubHash(expB36 + HUB_SECRET);
    return `EMERALD-${expB36}-${hash}`;
}

/** Return human-readable expiry string (UTC). */
function expiryString() {
    const ms = Date.now() + KEY_DURATION_SECS * 1000;
    return new Date(ms).toUTCString();
}

// ─── DISCORD CLIENT ───────────────────────────────────────────────────────────

const client = new Client({
    intents: [GatewayIntentBits.Guilds],
});

// Register /getkey slash command
async function registerCommands() {
    const commands = [
        new SlashCommandBuilder()
            .setName("getkey")
            .setDescription("Get a 72-hour EmeraldHub key (sent via DM).")
            .toJSON(),
        new SlashCommandBuilder()
            .setName("keyinfo")
            .setDescription("Check how long your current key is valid for.")
            .addStringOption(opt =>
                opt.setName("key")
                   .setDescription("Your EMERALD-... key")
                   .setRequired(true)
            )
            .toJSON(),
        new SlashCommandBuilder()
            .setName("hubinfo")
            .setDescription("Show EmeraldHub information and links.")
            .toJSON(),
    ];

    const rest = new REST({ version: "10" }).setToken(TOKEN);
    try {
        if (GUILD_ID) {
            // Guild commands update instantly — great for testing
            await rest.put(Routes.applicationGuildCommands(client.user.id, GUILD_ID), { body: commands });
            console.log(`[EmeraldBot] Slash commands registered to guild ${GUILD_ID}`);
        } else {
            // Global commands take up to 1 hour to propagate
            await rest.put(Routes.applicationCommands(client.user.id), { body: commands });
            console.log("[EmeraldBot] Slash commands registered globally");
        }
    } catch (err) {
        console.error("[EmeraldBot] Failed to register commands:", err);
    }
}

client.once("ready", async () => {
    console.log(`[EmeraldBot] Logged in as ${client.user.tag}`);
    client.user.setActivity("🟢 EmeraldHub | /getkey", { type: 3 /* Watching */ });
    await registerCommands();
});

// ─── COMMAND HANDLERS ─────────────────────────────────────────────────────────

client.on("interactionCreate", async (interaction) => {
    if (!interaction.isChatInputCommand()) return;

    // ── /getkey ──────────────────────────────────────────────────────────────
    if (interaction.commandName === "getkey") {
        await interaction.deferReply({ ephemeral: true });

        // Channel gate
        if (KEYGEN_CHANNEL_ID && interaction.channelId !== KEYGEN_CHANNEL_ID) {
            return interaction.editReply({
                content: `❌ Key generation is only available in <#${KEYGEN_CHANNEL_ID}>.`,
            });
        }

        // Role gate
        if (REQUIRED_ROLE_ID) {
            const member = interaction.guild
                ? await interaction.guild.members.fetch(interaction.user.id).catch(() => null)
                : null;
            if (!member || !member.roles.cache.has(REQUIRED_ROLE_ID)) {
                return interaction.editReply({
                    content: `❌ You need the <@&${REQUIRED_ROLE_ID}> role to get a key.`,
                });
            }
        }

        // Cooldown gate — one key per 72 hours
        const { onCooldown, secondsLeft } = checkCooldown(interaction.user.id);
        if (onCooldown) {
            const hrs  = Math.floor(secondsLeft / 3600);
            const mins = Math.floor((secondsLeft % 3600) / 60);
            const secs = secondsLeft % 60;

            const cooldownEmbed = new EmbedBuilder()
                .setColor(0xEF4444)
                .setTitle("⏳  You already have an active key")
                .setDescription("You can only get one key every **72 hours**.\nYour current key is still valid — paste it into EmeraldHub.")
                .addFields({
                    name: "⏱️ Next key available in",
                    value: `**${hrs}h ${mins}m ${secs}s**`,
                    inline: false,
                })
                .setFooter({ text: "EmeraldHub • Run /keyinfo to check your key" })
                .setTimestamp();

            return interaction.editReply({ embeds: [cooldownEmbed] });
        }

        const key    = generateKey();
        const expiry = expiryString();

        // DM the key
        try {
            const dmEmbed = new EmbedBuilder()
                .setColor(0x10B981)
                .setTitle("🔑  Your EmeraldHub Key")
                .setDescription(`\`\`\`\n${key}\n\`\`\``)
                .addFields(
                    { name: "⏳ Expires",    value: expiry,     inline: false },
                    { name: "⏱️ Valid for",  value: "72 hours", inline: true  },
                    { name: "🎮 How to use", value: "Open EmeraldHub → Main Game tab → paste the key above → click Unlock.", inline: false },
                )
                .setFooter({ text: "EmeraldHub • Do not share your key — one per 72 hours" })
                .setTimestamp();

            await interaction.user.send({ embeds: [dmEmbed] });

            // Record cooldown only after the DM succeeds
            recordCooldown(interaction.user.id);

            await interaction.editReply({
                content: "✅ **Your key has been sent via DM!**\nCheck your DMs — it expires in **72 hours**. You won't be able to get another key until this one expires.",
            });

            console.log(`[EmeraldBot] Key issued to ${interaction.user.tag} (${interaction.user.id}) — expires ${expiry}`);
        } catch {
            await interaction.editReply({
                content: "❌ I couldn't DM you — please enable DMs from server members and try again.",
            });
        }
    }

    // ── /keyinfo ─────────────────────────────────────────────────────────────
    if (interaction.commandName === "keyinfo") {
        await interaction.deferReply({ ephemeral: true });

        const raw = interaction.options.getString("key", true).trim().toUpperCase();
        const match = raw.match(/^EMERALD-([A-Z0-9]+)-(\d{7})$/);

        if (!match) {
            return interaction.editReply({
                content: "❌ Invalid key format. Keys look like: `EMERALD-XXXXX-0000000`",
            });
        }

        const [, expB36, hash] = match;
        const expectedHash = hubHash(expB36 + HUB_SECRET);

        if (hash !== expectedHash) {
            return interaction.editReply({ content: "❌ Key signature is invalid — this key was not generated by EmeraldHub." });
        }

        const expiry  = parseInt(expB36, 36);
        const now     = Math.floor(Date.now() / 1000);
        const remaining = expiry - now;

        if (remaining <= 0) {
            return interaction.editReply({
                content: "⚠️ This key has **expired**. Run `/getkey` to get a fresh one.",
            });
        }

        const hrs  = Math.floor(remaining / 3600);
        const mins = Math.floor((remaining % 3600) / 60);

        const embed = new EmbedBuilder()
            .setColor(0x10B981)
            .setTitle("✅  Key is Valid")
            .addFields(
                { name: "⏳ Time Remaining", value: `${hrs}h ${mins}m`,                    inline: true },
                { name: "📅 Expires At",     value: new Date(expiry * 1000).toUTCString(), inline: false },
            )
            .setFooter({ text: "EmeraldHub Key Checker" });

        return interaction.editReply({ embeds: [embed] });
    }

    // ── /hubinfo ─────────────────────────────────────────────────────────────
    if (interaction.commandName === "hubinfo") {
        const embed = new EmbedBuilder()
            .setColor(0x10B981)
            .setTitle("🟢  EmeraldHub")
            .setDescription("A premium Roblox script hub with keyless universal scripts and 72-hour keyed game scripts.")
            .addFields(
                { name: "🌐 Universal Scripts", value: "Keyless — work in any game",        inline: true },
                { name: "🔐 Main Game Scripts", value: "72-hour key via `/getkey`",         inline: true },
                { name: "⏱️ Key Duration",      value: "72 hours per key",                  inline: true },
                { name: "🤖 Get a Key",         value: "Run `/getkey` in this server",      inline: false },
                { name: "✅ Check a Key",       value: "Run `/keyinfo` with your key",       inline: false },
            )
            .setFooter({ text: "EmeraldHub • Keys are per-device" })
            .setTimestamp();

        return interaction.reply({ embeds: [embed], ephemeral: true });
    }
});

// ─── LOGIN ────────────────────────────────────────────────────────────────────

client.login(TOKEN).catch(err => {
    console.error("[EmeraldBot] Login failed:", err.message);
    process.exit(1);
});
