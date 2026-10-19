#!/usr/bin/env bash
set -euo pipefail


# --- Telegram (from @BotFather) -------------------------------------------
# Already loaded from docker compose environment variables

# TELEGRAM_AGY_BOT_TOKEN="123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ_1234567"
# TELEGRAM_AGY_BOT_USERNAME="your_bot_username"
# ALLOWED_USERS="123456789"

# TELEGRAM_CLAUDE_BOT_TOKEN="1234567890:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"   
# TELEGRAM_CLAUDE_BOT_USERNAME="your_bot_username" 
# ALLOWED_USERS="123456789"      

# ==========================================================
# Antigravity (AGY) Telegram Bot
# ==========================================================

echo "==> 1. Creating configuration directories..."
CONFIG_DIR="/root/.config/agy-telegram"
STATE_DIR="/var/lib/agy-telegram"
TEMP_DIR="/tmp/agy-telegram"
AGY_ENV_FILE="${CONFIG_DIR}/.env"

mkdir -p "${CONFIG_DIR}" "${STATE_DIR}" "${TEMP_DIR}"
chmod 700 "${CONFIG_DIR}" "${STATE_DIR}"

echo "==> 2. Generating configuration file at ${AGY_ENV_FILE}..."

TELEGRAM_PRIVATE_ONLY="1"
TELEGRAM_MAX_MESSAGE_CHARS="3900"

AGY_BIN="/root/.local/bin/agy"
AGY_WORKSPACE="/workspace"
AGY_PROJECTS_ROOT="/workspace"
AGY_DB_PATH="/root/.gemini/antigravity-cli/conversation_summaries.db"
AGY_MODE="accept-edits"
AGY_EFFORT="high"
AGY_MODEL="gemini-3.8-flash-high"
AGY_SANDBOX="0"
AGY_ALLOW_SANDBOX_DISABLE="1"
AGY_ALLOW_DANGEROUSLY_SKIP_PERMISSIONS="1"
AGY_TIMEOUT_MS="1800000"
AGY_MAX_OUTPUT_BYTES="20000000"
MAX_QUEUE_SIZE="8"
STATE_FILE="/var/lib/agy-telegram/state.json"
TEMP_DIR="/tmp/agy-telegram"
LOG_LEVEL="info"


cat > "${AGY_ENV_FILE}" <<EOF 
# ==========================================================
# Telegram Bot Configuration
# ==========================================================
# 1. Obtain from @BotFather in Telegram
TELEGRAM_BOT_TOKEN=${TELEGRAM_AGY_BOT_TOKEN}
TELEGRAM_BOT_USERNAME=${TELEGRAM_AGY_BOT_USERNAME}

# 2. Your numeric Telegram User ID (e.g. from @userinfobot). Comma-separated for multiple.
TELEGRAM_ALLOWED_USER_IDS=${ALLOWED_USERS}

# Optional: Restrict to private chats only (recommended: 1)
TELEGRAM_PRIVATE_ONLY=${TELEGRAM_PRIVATE_ONLY}
TELEGRAM_MAX_MESSAGE_CHARS=${TELEGRAM_MAX_MESSAGE_CHARS}

# ==========================================================
# Antigravity (AGY) CLI Integration
# ==========================================================
AGY_BIN=${AGY_BIN}
AGY_WORKSPACE=${AGY_WORKSPACE}
AGY_PROJECTS_ROOT=${AGY_PROJECTS_ROOT}
AGY_DB_PATH=${AGY_DB_PATH}

# Execution Settings: 'accept-edits' or 'plan'
AGY_MODE=${AGY_MODE}
AGY_EFFORT=${AGY_EFFORT}
AGY_MODEL=${AGY_MODEL}

# Permissions & Sandbox
# In container environments, set AGY_ALLOW_DANGEROUSLY_SKIP_PERMISSIONS=1 so AGY tools run unattended
AGY_SANDBOX=${AGY_SANDBOX}
AGY_ALLOW_SANDBOX_DISABLE=${AGY_ALLOW_SANDBOX_DISABLE}
AGY_ALLOW_DANGEROUSLY_SKIP_PERMISSIONS=${AGY_ALLOW_DANGEROUSLY_SKIP_PERMISSIONS}

# Timeouts and Buffer limits
AGY_TIMEOUT_MS=${AGY_TIMEOUT_MS}
AGY_MAX_OUTPUT_BYTES=${AGY_MAX_OUTPUT_BYTES}
MAX_QUEUE_SIZE=${MAX_QUEUE_SIZE}

# State & Temp storage
STATE_FILE=${STATE_FILE}
TEMP_DIR=${TEMP_DIR}
LOG_LEVEL=${LOG_LEVEL}

# ==========================================================
# Optional: Speech-to-Text (STT) & Text-to-Speech (TTS)
# ==========================================================
# Options for STT_PROVIDER: none | agy | gemini | whisper-local
STT_PROVIDER=none
# STT_GEMINI_API_KEY=AIzaSy_dummy_key_here
# STT_LANGUAGE=en

# Options for TTS_MODE: off | auto | voice-only | voice-and-text
TTS_MODE=off
TTS_VOICE=en-US-AndrewMultilingualNeural
TTS_BIN=/usr/local/bin/edge-tts
EOF

chmod 600 "${AGY_ENV_FILE}"
echo "==> Wrote ${AGY_ENV_FILE} (chmod 600)"

# ==========================================================
# Claude Code Telegram Bot
# ==========================================================

CONFIG_CLAUDE_DIR="/root/.config/claude-telegram-bot"
CLAUDE_ENV_FILE="${CONFIG_CLAUDE_DIR}/.env"

mkdir -p "${CONFIG_CLAUDE_DIR}"
chmod 700 "${CONFIG_CLAUDE_DIR}"


# --- Claude (this container already has `claude` CLI authenticated, so we
#     leave ANTHROPIC_API_KEY empty and let the SDK use CLI credentials) ---
USE_SDK="true"

# --- Security / access control --------------------------------------------
APPROVED_DIRECTORY="/workspace" # DUMMY — directory Claude may read/write/edit

# --- Misc toggles (all safe defaults; left explicit for clarity) ----------
ENVIRONMENT="production"
DEVELOPMENT_MODE="false"
LOG_LEVEL="INFO"
ENABLE_MCP="false"
ENABLE_GIT_INTEGRATION="true"
ENABLE_FILE_UPLOADS="true"
ENABLE_QUICK_ACTIONS="true"
ENABLE_VOICE_MESSAGES="false"
ENABLE_API_SERVER="false"
ENABLE_SCHEDULER="false"

# ---------------------------------------------------------------------------
# 2. Write the .env with dummy secrets
# ---------------------------------------------------------------------------
cat > "${CLAUDE_ENV_FILE}" <<EOF
# Claude Code Telegram Bot — DUMMY CONFIGURATION
# Replace every placeholder below with real values before using for real.
# See: https://github.com/overwirehq/claude-code-telegram

# === REQUIRED (from @BotFather) ===
TELEGRAM_BOT_TOKEN=${TELEGRAM_CLAUDE_BOT_TOKEN}
TELEGRAM_BOT_USERNAME=${TELEGRAM_CLAUDE_BOT_USERNAME}

# === Claude auth ===
USE_SDK=${USE_SDK}
# ANTHROPIC_API_KEY=sk-ant-...   # leave empty to use the already-authenticated CLI

# === Security ===
ALLOWED_USERS=${ALLOWED_USERS}
APPROVED_DIRECTORY=${APPROVED_DIRECTORY}

# === Runtime ===
ENVIRONMENT=${ENVIRONMENT}
DEVELOPMENT_MODE=${DEVELOPMENT_MODE}
LOG_LEVEL=${LOG_LEVEL}

# === Feature flags ===
ENABLE_MCP=${ENABLE_MCP}
ENABLE_GIT_INTEGRATION=${ENABLE_GIT_INTEGRATION}
ENABLE_FILE_UPLOADS=${ENABLE_FILE_UPLOADS}
ENABLE_QUICK_ACTIONS=${ENABLE_QUICK_ACTIONS}
ENABLE_VOICE_MESSAGES=${ENABLE_VOICE_MESSAGES}
ENABLE_API_SERVER=${ENABLE_API_SERVER}
ENABLE_SCHEDULER=${ENABLE_SCHEDULER}
EOF
chmod 600 "${CLAUDE_ENV_FILE}"
echo "==> Wrote ${CLAUDE_ENV_FILE} (chmod 600)"


# ==========================================================
# PM2 Configuration and Startup
# ==========================================================

# Configure both bots as separate PM2 processes, each with its own .env file
CONFIG_PM2_DIR="/root/.config/pm2"
PM2_CONFIG_FILE="${CONFIG_PM2_DIR}/ecosystem.config.js"

mkdir -p "${CONFIG_PM2_DIR}"
chmod 700 "${CONFIG_PM2_DIR}"

cat > "${PM2_CONFIG_FILE}" <<EOF
module.exports = {
  apps: [
    {
      name: "claude-bot-telegram",
      script: "set -a && source ${CLAUDE_ENV_FILE} && set +a && /root/.local/bin/claude-telegram-bot"
    },
    {
      name: "agy-bot-telegram", 
      script: "/usr/local/bin/agy-telegram",
      env_file: "${AGY_ENV_FILE}"
    },
    {
      name: "kimaki-bot-discord",
      script: "kimaki --data-dir /root/.kimaki",
      autorestart: true,
      env: {
        NODE_ENV: "production",
        KIMAKI_BOT_TOKEN: process.env.DISCORD_BOT_TOKEN,
        XDG_CONFIG_HOME: process.env.XDG_CONFIG_HOME,
        XDG_DATA_HOME: process.env.XDG_DATA_HOME,
        OPENCODE_CONFIG: process.env.OPENCODE_CONFIG
      }
    }
  ]
}

EOF
chmod 700 "${PM2_CONFIG_FILE}"

# Start both bots using PM2
exec pm2-runtime start "${PM2_CONFIG_FILE}"



