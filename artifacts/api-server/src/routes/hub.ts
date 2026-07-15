import { Router } from "express";
import { readFileSync } from "fs";
import { join } from "path";

const router = Router();

// Serve the EmeraldHub Lua script so executors can loadstring() it.
// process.cwd() = artifacts/api-server/ at runtime, so go up two levels to workspace root.
const LUA_PATH = join(process.cwd(), "../../ScriptHub/Main.lua");

router.get("/hub.lua", (_req, res) => {
  try {
    const script = readFileSync(LUA_PATH, "utf8");
    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    // Prevent caching so users always get the latest version
    res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    res.send(script);
  } catch (err) {
    res.status(500).send("-- EmeraldHub: script not found on server");
  }
});

export default router;
