/**
 * EmeraldHub Discord Bot v2.0
 * Features: key system, keydrop, killswitch, HWID reset, blacklist, whitelist,
 * testkey, 6-hour status updates, update logs, buy panel, loadstring in DM.
 */

require("dotenv").config();
const fs = require("fs");
const {
    Client, GatewayIntentBits, SlashCommandBuilder, REST, Routes,
    EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle,
    PermissionFlagsBits, ChannelType,
} = require("discord.js");

// ─── CONFIG ───────────────────────────────────────────────────────────────────
const TOKEN             = process.env.DISCORD_TOKEN;
const HUB_SECRET        = process.env.HUB_SECRET || "CHANGE_THIS_TO_YOUR_OWN_SECRET";
const GUILD_ID          = process.env.GUILD_ID   || null;
const KEY_DURATION_SECS = 100 * 365 * 24 * 60 * 60; // ~100 years = lifetime
const LOADSTRING_URL    =
    "https://raw.githubusercontent.com/f26427480-hash/emeraldhub2/main/ScriptHub/Main.lua";

if (!TOKEN) { console.error("[EmeraldBot] ERROR: Set DISCORD_TOKEN."); process.exit(1); }
if (HUB_SECRET === "CHANGE_THIS_TO_YOUR_OWN_SECRET") {
    console.warn("[EmeraldBot] WARNING: HUB_SECRET is still the default.");
}

// ─── PERSISTENT STORAGE ───────────────────────────────────────────────────────
const FILES = {
    cooldowns:  "./cooldowns.json",
    config:     "./config.json",
    blacklist:  "./blacklist.json",
    whitelist:  "./whitelist.json",
};

function load(file, def) {
    try { return JSON.parse(fs.readFileSync(file, "utf8")); }
    catch { return typeof def === "function" ? def() : def; }
}
function save(file, data) {
    fs.writeFileSync(file, JSON.stringify(data, null, 2));
}

const loadConfig    = () => load(FILES.config,    { killswitch: false, statusChannel: null, updateLogChannel: null });
const saveConfig    = (c) => save(FILES.config, c);
const loadBlacklist = () => load(FILES.blacklist, { discord: [], roblox: [] });
const saveBlacklist = (b) => save(FILES.blacklist, b);
const loadWhitelist = () => load(FILES.whitelist, []);
const saveWhitelist = (w) => save(FILES.whitelist, w);
const loadCooldowns = () => load(FILES.cooldowns, {});
const saveCooldowns = (m) => save(FILES.cooldowns, m);

// ─── KEY SYSTEM ───────────────────────────────────────────────────────────────
function hubHash(s) {
    const MOD = 1_000_000_007n;
    let h = 0n;
    for (let i = 0; i < s.length; i++) {
        h = (h * 31n + BigInt(s.charCodeAt(i))) % MOD;
    }
    return (h % 10_000_000n).toString().padStart(7, "0");
}

function generateKey() {
    const expiry = Math.floor(Date.now() / 1000) + KEY_DURATION_SECS;
    const expB36 = expiry.toString(36).toUpperCase();
    return `FLUX-${expB36}-${hubHash(expB36 + HUB_SECRET)}`;
}

function validateKey(raw) {
    const key   = raw.trim().toUpperCase();
    const match = key.match(/^EMERALD-([A-Z0-9]+)-(\d{7})$/);
    if (!match) return { ok: false, reason: "Invalid format. Keys look like: `FLUX-XXXXX-0000000`" };
    const [, expB36, hash] = match;
    if (hash !== hubHash(expB36 + HUB_SECRET)) return { ok: false, reason: "Invalid signature — key not issued by FluxHub." };
    const expiry    = parseInt(expB36, 36);
    const remaining = expiry - Math.floor(Date.now() / 1000);
    if (remaining <= 0) return { ok: false, reason: "Key has expired. Run `/getkey` for a fresh one." };
    return { ok: true, remaining, expiry };
}

function fmtExpiry() { return "Never — Lifetime Key"; }
function fmtTime(secs) {
    if (secs > 365 * 24 * 3600) return "Lifetime";
    return `${Math.floor(secs / 3600)}h ${Math.floor((secs % 3600) / 60)}m`;
}

// ─── COOLDOWN HELPERS ─────────────────────────────────────────────────────────
function checkCooldown(userId) {
    const map      = loadCooldowns();
    const issuedAt = map[userId];
    if (!issuedAt) return { onCooldown: false, secondsLeft: 0 };
    const left = issuedAt + KEY_DURATION_SECS - Math.floor(Date.now() / 1000);
    return left > 0 ? { onCooldown: true, secondsLeft: left } : { onCooldown: false, secondsLeft: 0 };
}
function recordCooldown(userId) {
    const map = loadCooldowns(); map[userId] = Math.floor(Date.now() / 1000); saveCooldowns(map);
}
function resetCooldown(userId) {
    const map = loadCooldowns(); delete map[userId]; saveCooldowns(map);
}

// ─── ADMIN CHECK ──────────────────────────────────────────────────────────────
function isAdmin(interaction) {
    return interaction.member?.permissions?.has(PermissionFlagsBits.Administrator)
        || interaction.guild?.ownerId === interaction.user.id;
}

// ─── CLIENT ───────────────────────────────────────────────────────────────────
const client = new Client({ intents: [GatewayIntentBits.Guilds] });

// ─── COMMAND DEFINITIONS ──────────────────────────────────────────────────────
async function registerCommands() {
    const cmds = [
        // ── User commands ──────────────────────────────────────────────────────
        new SlashCommandBuilder()
            .setName("getkey")
            .setDescription("Get a free lifetime FluxHub key (sent via DM)."),

        new SlashCommandBuilder()
            .setName("keyinfo")
            .setDescription("Check how long a key is valid.")
            .addStringOption(o =>
                o.setName("key").setDescription("Your FluxHub... key").setRequired(true)),

        new SlashCommandBuilder()
            .setName("hubinfo")
            .setDescription("Show FluxHub info and links."),

        // ── Admin commands ─────────────────────────────────────────────────────
        new SlashCommandBuilder()
            .setName("keydrop")
            .setDescription("[Admin] Drop a free key publicly in this channel."),

        new SlashCommandBuilder()
            .setName("killswitch")
            .setDescription("[Admin] Enable or disable the hub globally.")
            .addStringOption(o =>
                o.setName("state").setDescription("on or off").setRequired(true)
                 .addChoices({ name: "on (disable hub)", value: "on" }, { name: "off (re-enable hub)", value: "off" })),

        new SlashCommandBuilder()
            .setName("resethwid")
            .setDescription("[Admin] Reset a user's HWID/cooldown so they can get a new key.")
            .addUserOption(o =>
                o.setName("user").setDescription("User to reset").setRequired(true)),

        new SlashCommandBuilder()
            .setName("blacklist")
            .setDescription("[Admin] Add or remove a Discord/Roblox ID from the blacklist.")
            .addStringOption(o =>
                o.setName("action").setDescription("add or remove").setRequired(true)
                 .addChoices({ name: "add", value: "add" }, { name: "remove", value: "remove" }))
            .addStringOption(o =>
                o.setName("type").setDescription("discord or roblox").setRequired(true)
                 .addChoices({ name: "discord", value: "discord" }, { name: "roblox", value: "roblox" }))
            .addStringOption(o =>
                o.setName("id").setDescription("ID to add or remove").setRequired(true)),

        new SlashCommandBuilder()
            .setName("whitelist")
            .setDescription("[Admin] Add or remove a user from the whitelist (bypasses cooldown).")
            .addStringOption(o =>
                o.setName("action").setDescription("add or remove").setRequired(true)
                 .addChoices({ name: "add", value: "add" }, { name: "remove", value: "remove" }))
            .addUserOption(o =>
                o.setName("user").setDescription("User to whitelist").setRequired(true)),

        new SlashCommandBuilder()
            .setName("testkey")
            .setDescription("[Admin] Validate and inspect any FluxHub key.")
            .addStringOption(o =>
                o.setName("key").setDescription("Key to test").setRequired(true)),

        new SlashCommandBuilder()
            .setName("setstatus")
            .setDescription("[Admin] Set the channel for automatic 6-hour status updates.")
            .addChannelOption(o =>
                o.setName("channel").setDescription("Channel to post status in").setRequired(true)
                 .addChannelTypes(ChannelType.GuildText)),

        new SlashCommandBuilder()
            .setName("setupdatelogs")
            .setDescription("[Admin] Set the channel for event/update logs.")
            .addChannelOption(o =>
                o.setName("channel").setDescription("Channel for logs").setRequired(true)
                 .addChannelTypes(ChannelType.GuildText)),

        new SlashCommandBuilder()
            .setName("buypanel")
            .setDescription("[Admin] Post the FluxHub key panel in this channel."),
    ].map(c => c.toJSON());

    const rest = new REST({ version: "10" }).setToken(TOKEN);
    if (GUILD_ID) {
        await rest.put(Routes.applicationGuildCommands(client.user.id, GUILD_ID), { body: cmds });
        console.log(`[EmeraldBot] Commands registered to guild ${GUILD_ID}`);
    } else {
        await rest.put(Routes.applicationCommands(client.user.id), { body: cmds });
        console.log("[EmeraldBot] Commands registered globally");
    }
}

// ─── LOG HELPER ───────────────────────────────────────────────────────────────
async function logEvent(msg) {
    const cfg = loadConfig();
    if (!cfg.updateLogChannel) return;
    try {
        const ch = await client.channels.fetch(cfg.updateLogChannel);
        if (ch) await ch.send(`\`[${new Date().toUTCString()}]\` ${msg}`);
    } catch {}
}

// ─── STATUS EMBED ─────────────────────────────────────────────────────────────
function buildStatusEmbed() {
    const cfg       = loadConfig();
    const bl        = loadBlacklist();
    const wl        = loadWhitelist();
    const cooldowns = loadCooldowns();
    const now       = Math.floor(Date.now() / 1000);
    const active    = Object.values(cooldowns).filter(t => t + KEY_DURATION_SECS > now).length;

    return new EmbedBuilder()
        .setColor(cfg.killswitch ? 0xEF4444 : 0x10B981)
        .setTitle(cfg.killswitch ? "🔴  EmeraldHub — OFFLINE" : "🟢  FluxHub — ONLINE")
        .setDescription(cfg.killswitch
            ? "The hub has been disabled by an administrator."
            : "The hub is online and accepting keys.")
        .addFields(
            { name: "🔑 Active Keys",    value: String(active),                         inline: true },
            { name: "🚫 Blacklisted",    value: `${bl.discord.length + bl.roblox.length} IDs`, inline: true },
            { name: "⭐ Whitelisted",    value: `${wl.length} users`,                   inline: true },
            { name: "⏱️ Key Duration",  value: "Lifetime",                             inline: true },
            { name: "🔒 Killswitch",     value: cfg.killswitch ? "ON 🔴" : "OFF 🟢",   inline: true },
        )
        .setFooter({ text: "FluxHub Status • Auto-updated every 6h" })
        .setTimestamp();
}

// ─── KEY DM ───────────────────────────────────────────────────────────────────
async function sendKeyDM(user, key) {
    const embed = new EmbedBuilder()
        .setColor(0x10B981)
        .setTitle("🔑  Your FluxHub Key")
        .setDescription(`\`\`\`\n${key}\n\`\`\``)
        .addFields(
            { name: "⏳ Expires",       value: "Never — Lifetime Key",       inline: false },
            { name: "⏱️ Valid for",    value: "Lifetime",                   inline: true  },
            { name: "📋 Loadstring",   value: `\`\`\`lua\nloadstring(game:HttpGet("${LOADSTRING_URL}"))()\`\`\``, inline: false },
            { name: "🎮 How to use",   value: "1. Run the loadstring above in your executor.\n2. Go to the **Main Game** tab → paste your key → click **Unlock**.", inline: false },
        )
        .setFooter({ text: "FluxHub • Do not share your key — Lifetime keys never expire" })
        .setTimestamp();
    await user.send({ embeds: [embed] });
}

// ─── READY ────────────────────────────────────────────────────────────────────
client.once("ready", async () => {
    console.log(`[EmeraldBot] Logged in as ${client.user.tag}`);
    client.user.setActivity("🟢 FluxHub | /getkey", { type: 3 });
    await registerCommands();

    // 6-hour status update loop
    setInterval(async () => {
        const cfg = loadConfig();
        if (!cfg.statusChannel) return;
        try {
            const ch = await client.channels.fetch(cfg.statusChannel);
            if (ch) await ch.send({ embeds: [buildStatusEmbed()] });
        } catch {}
    }, 6 * 60 * 60 * 1000);
});

// ─── INTERACTIONS ─────────────────────────────────────────────────────────────
client.on("interactionCreate", async (interaction) => {
    // Button: "Get Free Key" from buy panel
    if (interaction.isButton() && interaction.customId === "emerald_getkey") {
        await interaction.deferReply({ ephemeral: true });
        return handleGetKey(interaction);
    }

    if (!interaction.isChatInputCommand()) return;

    const handlers = {
        getkey:        handleGetKey,
        keyinfo:       handleKeyInfo,
        hubinfo:       handleHubInfo,
        keydrop:       handleKeyDrop,
        killswitch:    handleKillswitch,
        resethwid:     handleResetHwid,
        blacklist:     handleBlacklist,
        whitelist:     handleWhitelist,
        testkey:       handleTestKey,
        setstatus:     handleSetStatus,
        setupdatelogs: handleSetUpdateLogs,
        buypanel:      handleBuyPanel,
    };
    const fn = handlers[interaction.commandName];
    if (fn) fn(interaction);
});

// ─── /getkey ──────────────────────────────────────────────────────────────────
async function handleGetKey(interaction) {
    if (!interaction.deferred && !interaction.replied) {
        await interaction.deferReply({ ephemeral: true });
    }

    const userId = interaction.user.id;
    const cfg    = loadConfig();

    if (cfg.killswitch) {
        return interaction.editReply({ content: "🔴 **FluxHub is currently offline.** Check back later." });
    }

    const bl = loadBlacklist();
    if (bl.discord.includes(userId)) {
        return interaction.editReply({ content: "🚫 You are blacklisted from FluxHub." });
    }

    const whitelisted = loadWhitelist().includes(userId);

    if (!whitelisted) {
        const { onCooldown, secondsLeft } = checkCooldown(userId);
        if (onCooldown) {
            const hrs  = Math.floor(secondsLeft / 3600);
            const mins = Math.floor((secondsLeft % 3600) / 60);
            const secs = secondsLeft % 60;
            return interaction.editReply({
                embeds: [new EmbedBuilder()
                    .setColor(0xEF4444)
                    .setTitle("⏳  You already have an active key")
                    .setDescription("You already have a **Lifetime key** — it never expires.\nPaste it into FluxHub to use it.")
                    .addFields({ name: "⏱️ Time left", value: `**${hrs}h ${mins}m ${secs}s**` })
                    .setFooter({ text: "FluxHub • Run /keyinfo to check your key" })
                    .setTimestamp()],
            });
        }
    }

    const key = generateKey();
    try {
        await sendKeyDM(interaction.user, key);
        if (!whitelisted) recordCooldown(userId);

        await interaction.editReply({
            content: `✅ **Lifetime key sent via DM!** Check your DMs — your key never expires.${whitelisted ? "\n⭐ *Whitelisted — cooldown bypassed.*" : ""}`,
        });

        await logEvent(`🔑 Lifetime key issued to **${interaction.user.tag}** (\`${userId}\`)`);
        console.log(`[EmeraldBot] Key issued to ${interaction.user.tag} (${userId})`);
    } catch {
        await interaction.editReply({ content: "❌ Couldn't DM you — please enable DMs from server members and try again." });
    }
}

// ─── /keyinfo ─────────────────────────────────────────────────────────────────
async function handleKeyInfo(interaction) {
    await interaction.deferReply({ ephemeral: true });
    const result = validateKey(interaction.options.getString("key", true));

    if (!result.ok) return interaction.editReply({ content: `❌ ${result.reason}` });

    return interaction.editReply({
        embeds: [new EmbedBuilder()
            .setColor(0x10B981)
            .setTitle("✅  Key is Valid")
            .addFields(
                { name: "⏳ Time Remaining", value: fmtTime(result.remaining),                       inline: true  },
                { name: "📅 Expires At",     value: new Date(result.expiry * 1000).toUTCString(),    inline: false },
            )
            .setFooter({ text: "FluxHub Key Checker" })],
    });
}

// ─── /hubinfo ─────────────────────────────────────────────────────────────────
async function handleHubInfo(interaction) {
    return interaction.reply({
        embeds: [new EmbedBuilder()
            .setColor(0x10B981)
            .setTitle("🟢  FluxHub")
            .setDescription("A Roblox script hub with keyless universal scripts and 72-hour keyed game scripts.")
            .addFields(
                { name: "🌐 Universal Scripts", value: "Keyless — any game",                inline: true  },
                { name: "🔐 Game Scripts",       value: "72-hour key via `/getkey`",        inline: true  },
                { name: "📋 Loadstring",         value: `\`\`\`lua\nloadstring(game:HttpGet("${LOADSTRING_URL}"))()\`\`\``, inline: false },
                { name: "🤖 Get a Key",          value: "Run `/getkey` in this server",     inline: false },
            )
            .setFooter({ text: "EmeraldHub" })
            .setTimestamp()],
        ephemeral: true,
    });
}

// ─── /keydrop ─────────────────────────────────────────────────────────────────
async function handleKeyDrop(interaction) {
    await interaction.deferReply({ ephemeral: true });
    if (!isAdmin(interaction)) return interaction.editReply({ content: "❌ Admin only." });

    const key = generateKey();
    await interaction.channel.send({
        embeds: [new EmbedBuilder()
            .setColor(0xF59E0B)
            .setTitle("🎁  FREE KEY DROP!")
            .setDescription(`First to use it wins!\n\n\`\`\`\n${key}\n\`\`\``)
            .addFields(
                { name: "📋 Loadstring", value: `\`\`\`lua\nloadstring(game:HttpGet("${LOADSTRING_URL}"))()\`\`\``, inline: false },
                { name: "⏳ Expires",    value: "Never — Lifetime Key",                                               inline: true  },
            )
            .setFooter({ text: "FluxHub • Lifetime keys — never expire" })
            .setTimestamp()],
    });

    await interaction.editReply({ content: "✅ Key dropped!" });
    await logEvent(`🎁 Key drop in <#${interaction.channelId}> by **${interaction.user.tag}**`);
}

// ─── /killswitch ──────────────────────────────────────────────────────────────
async function handleKillswitch(interaction) {
    await interaction.deferReply({ ephemeral: true });
    if (!isAdmin(interaction)) return interaction.editReply({ content: "❌ Admin only." });

    const on  = interaction.options.getString("state") === "on";
    const cfg = loadConfig();
    cfg.killswitch = on;
    saveConfig(cfg);

    const label = on ? "🔴 ENABLED — hub is now offline." : "🟢 DISABLED — hub is back online.";
    await interaction.editReply({ content: `✅ Killswitch ${label}` });
    await logEvent(`${on ? "🔴" : "🟢"} Killswitch **${on ? "ENABLED" : "DISABLED"}** by **${interaction.user.tag}**`);

    if (cfg.statusChannel) {
        try {
            const ch = await client.channels.fetch(cfg.statusChannel);
            if (ch) await ch.send({ embeds: [buildStatusEmbed()] });
        } catch {}
    }
}

// ─── /resethwid ───────────────────────────────────────────────────────────────
async function handleResetHwid(interaction) {
    await interaction.deferReply({ ephemeral: true });
    if (!isAdmin(interaction)) return interaction.editReply({ content: "❌ Admin only." });

    const target = interaction.options.getUser("user", true);
    resetCooldown(target.id);

    await interaction.editReply({ content: `✅ HWID/cooldown reset for **${target.tag}** — they can now get a fresh key.` });
    await logEvent(`🔄 HWID reset for **${target.tag}** (\`${target.id}\`) by **${interaction.user.tag}**`);
}

// ─── /blacklist ───────────────────────────────────────────────────────────────
async function handleBlacklist(interaction) {
    await interaction.deferReply({ ephemeral: true });
    if (!isAdmin(interaction)) return interaction.editReply({ content: "❌ Admin only." });

    const action = interaction.options.getString("action");
    const type   = interaction.options.getString("type");   // "discord" | "roblox"
    const id     = interaction.options.getString("id").trim();
    const bl     = loadBlacklist();

    if (action === "add") {
        if (bl[type].includes(id)) return interaction.editReply({ content: `⚠️ \`${id}\` is already blacklisted.` });
        bl[type].push(id);
        saveBlacklist(bl);
        await interaction.editReply({ content: `✅ \`${id}\` added to the **${type}** blacklist.` });
        await logEvent(`🚫 **${type}** ID \`${id}\` blacklisted by **${interaction.user.tag}**`);
    } else {
        const idx = bl[type].indexOf(id);
        if (idx === -1) return interaction.editReply({ content: `⚠️ \`${id}\` is not in the blacklist.` });
        bl[type].splice(idx, 1);
        saveBlacklist(bl);
        await interaction.editReply({ content: `✅ \`${id}\` removed from the **${type}** blacklist.` });
        await logEvent(`✅ **${type}** ID \`${id}\` un-blacklisted by **${interaction.user.tag}**`);
    }
}

// ─── /whitelist ───────────────────────────────────────────────────────────────
async function handleWhitelist(interaction) {
    await interaction.deferReply({ ephemeral: true });
    if (!isAdmin(interaction)) return interaction.editReply({ content: "❌ Admin only." });

    const action = interaction.options.getString("action");
    const target = interaction.options.getUser("user", true);
    const wl     = loadWhitelist();

    if (action === "add") {
        if (wl.includes(target.id)) return interaction.editReply({ content: `⚠️ **${target.tag}** is already whitelisted.` });
        wl.push(target.id);
        saveWhitelist(wl);
        await interaction.editReply({ content: `✅ **${target.tag}** whitelisted — cooldown bypassed forever.` });
        await logEvent(`⭐ **${target.tag}** (\`${target.id}\`) whitelisted by **${interaction.user.tag}**`);
    } else {
        const idx = wl.indexOf(target.id);
        if (idx === -1) return interaction.editReply({ content: `⚠️ **${target.tag}** is not whitelisted.` });
        wl.splice(idx, 1);
        saveWhitelist(wl);
        await interaction.editReply({ content: `✅ **${target.tag}** removed from whitelist.` });
        await logEvent(`❌ **${target.tag}** (\`${target.id}\`) un-whitelisted by **${interaction.user.tag}**`);
    }
}

// ─── /testkey ─────────────────────────────────────────────────────────────────
async function handleTestKey(interaction) {
    await interaction.deferReply({ ephemeral: true });
    if (!isAdmin(interaction)) return interaction.editReply({ content: "❌ Admin only." });

    const result = validateKey(interaction.options.getString("key", true));

    if (!result.ok) {
        return interaction.editReply({
            embeds: [new EmbedBuilder()
                .setColor(0xEF4444)
                .setTitle("❌  Invalid Key")
                .setDescription(result.reason)
                .setFooter({ text: "EmeraldHub Admin — Key Tester" })],
        });
    }

    return interaction.editReply({
        embeds: [new EmbedBuilder()
            .setColor(0x10B981)
            .setTitle("✅  Key is Valid")
            .addFields(
                { name: "🔑 Key",            value: `\`${interaction.options.getString("key", true).trim().toUpperCase()}\``, inline: false },
                { name: "⏳ Time Remaining", value: fmtTime(result.remaining),                    inline: true  },
                { name: "📅 Expires At",     value: new Date(result.expiry * 1000).toUTCString(), inline: false },
            )
            .setFooter({ text: "EmeraldHub Admin — Key Tester" })],
    });
}

// ─── /setstatus ───────────────────────────────────────────────────────────────
async function handleSetStatus(interaction) {
    await interaction.deferReply({ ephemeral: true });
    if (!isAdmin(interaction)) return interaction.editReply({ content: "❌ Admin only." });

    const ch  = interaction.options.getChannel("channel", true);
    const cfg = loadConfig();
    cfg.statusChannel = ch.id;
    saveConfig(cfg);

    // Post an immediate status update
    try { await ch.send({ embeds: [buildStatusEmbed()] }); } catch {}

    await interaction.editReply({ content: `✅ Status updates will post to <#${ch.id}> every **6 hours**.` });
    await logEvent(`📢 Status channel set to <#${ch.id}> by **${interaction.user.tag}**`);
}

// ─── /setupdatelogs ───────────────────────────────────────────────────────────
async function handleSetUpdateLogs(interaction) {
    await interaction.deferReply({ ephemeral: true });
    if (!isAdmin(interaction)) return interaction.editReply({ content: "❌ Admin only." });

    const ch  = interaction.options.getChannel("channel", true);
    const cfg = loadConfig();
    cfg.updateLogChannel = ch.id;
    saveConfig(cfg);

    await interaction.editReply({ content: `✅ Update logs will be posted to <#${ch.id}>.` });
    try { await ch.send(`📋 **EmeraldHub update logs are now active in this channel.**`); } catch {}
}

// ─── /buypanel ────────────────────────────────────────────────────────────────
async function handleBuyPanel(interaction) {
    await interaction.deferReply({ ephemeral: true });
    if (!isAdmin(interaction)) return interaction.editReply({ content: "❌ Admin only." });

    const embed = new EmbedBuilder()
        .setColor(0x10B981)
        .setTitle("💎  EmeraldHub — Get Your Key")
        .setDescription("Click **Get Free Key** to get your **72-hour key** instantly via DM.\nYour key and loadstring will be sent together.")
        .addFields(
            { name: "📋 Loadstring",      value: `\`\`\`lua\nloadstring(game:HttpGet("${LOADSTRING_URL}"))()\`\`\``, inline: false },
            { name: "⏱️ Key Duration",   value: "Lifetime — never expires",                                           inline: true  },
            { name: "🎮 Supported Games", value: "Murder Mystery 2, Speed/Keyboard Escape, Steal a Brainrot & more",  inline: false },
        )
        .setFooter({ text: "EmeraldHub • Free lifetime keys — never expire" })
        .setTimestamp();

    const row = new ActionRowBuilder().addComponents(
        new ButtonBuilder()
            .setCustomId("emerald_getkey")
            .setLabel("🔑  Get Free Key")
            .setStyle(ButtonStyle.Success),
    );

    await interaction.channel.send({ embeds: [embed], components: [row] });
    await interaction.editReply({ content: "✅ Buy panel posted!" });
}

// ─── LOGIN ────────────────────────────────────────────────────────────────────
client.login(TOKEN).catch(err => {
    console.error("[EmeraldBot] Login failed:", err.message);
    process.exit(1);
});
