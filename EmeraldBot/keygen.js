/**
 * EmeraldHub — manual key generator
 * Usage: node EmeraldBot/keygen.js [hours] [name]
 *
 * Examples:
 *   node EmeraldBot/keygen.js                  → 72h key, no name
 *   node EmeraldBot/keygen.js 24               → 24h key, no name
 *   node EmeraldBot/keygen.js 48 "John"        → 48h key labelled John
 *   node EmeraldBot/keygen.js 168 "VIP User"   → 7-day key labelled VIP User
 */

require("dotenv").config();

const HUB_SECRET = process.env.HUB_SECRET || "CHANGE_THIS_TO_YOUR_OWN_SECRET";

// ── Parse args ────────────────────────────────────────────────────────────────
const args  = process.argv.slice(2);
const hours = parseFloat(args[0]) || 72;
const name  = args.slice(1).join(" ") || null;

if (isNaN(hours) || hours <= 0) {
    console.error("❌  Hours must be a positive number. Example: node keygen.js 48 John");
    process.exit(1);
}

const KEY_DURATION_SECS = Math.round(hours * 3600);

// ── Key generation (matches Lua hub hash) ─────────────────────────────────────
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

// ── Output ────────────────────────────────────────────────────────────────────
const key    = generateKey();
const expiry = new Date(Date.now() + KEY_DURATION_SECS * 1000).toUTCString();

const durationLabel = hours === 1 ? "1 hour"
    : hours % 24 === 0            ? `${hours / 24} day(s)`
    : `${hours} hour(s)`;

console.log("\n🔑  EmeraldHub Key");
console.log("─────────────────────────────────────────");
if (name) console.log(`Name:     ${name}`);
console.log(`Key:      ${key}`);
console.log(`Duration: ${durationLabel}`);
console.log(`Expires:  ${expiry}`);
console.log("─────────────────────────────────────────\n");
