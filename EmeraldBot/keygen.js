/**
 * EmeraldHub — manual key generator
 * Usage: node EmeraldBot/keygen.js
 * Generates a valid 72-hour EMERALD key using the same algorithm as the bot.
 */

require("dotenv").config();

const HUB_SECRET        = process.env.HUB_SECRET || "CHANGE_THIS_TO_YOUR_OWN_SECRET";
const KEY_DURATION_SECS = 72 * 60 * 60;

function hubHash(s) {
    const MOD = 1_000_000_007n;
    let h = 0n;
    for (let i = 0; i < s.length; i++) {
        h = (h * 31n + BigInt(s.charCodeAt(i))) % MOD;
    }
    return h.toString().padStart(7, "0");
}

function generateKey() {
    const expiry = Math.floor(Date.now() / 1000) + KEY_DURATION_SECS;
    const expB36 = expiry.toString(36).toUpperCase();
    const hash   = hubHash(expB36 + HUB_SECRET);
    return `EMERALD-${expB36}-${hash}`;
}

const key    = generateKey();
const expiry = new Date(Date.now() + KEY_DURATION_SECS * 1000).toUTCString();

console.log("\n🔑 EmeraldHub Key");
console.log("─────────────────────────────────");
console.log(`Key:     ${key}`);
console.log(`Expires: ${expiry}`);
console.log("─────────────────────────────────\n");
