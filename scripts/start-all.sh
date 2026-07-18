#!/bin/sh
# EmeraldHub production startup
# Runs the Discord bot in the background and the API server in the foreground.
# The API server keeps the process alive and provides the health check endpoint.

echo "[EmeraldHub] Starting Discord bot..."
cd /home/runner/workspace/EmeraldBot
node bot.js &
BOT_PID=$!
echo "[EmeraldHub] Discord bot running (PID $BOT_PID)"

echo "[EmeraldHub] Starting API server..."
cd /home/runner/workspace
exec node --enable-source-maps artifacts/api-server/dist/index.mjs
