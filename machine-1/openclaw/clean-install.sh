#!/usr/bin/env bash
set -e

# Clean existing data and create a new directory for OpenClaw data
rm -rf ./.openclaw-data \
&& mkdir -p ./.openclaw-data \
&& chown -R 1000:1000 ./.openclaw-data \
&& chmod 700 '.openclaw-data'

# Define the filename dynamically first (Recommended for readability)
ENV_FILE="./../../../secrets/_${PWD##*/}.env"
# Extract keys for later cleanup
KEYS=$(grep -v '^#' "$ENV_FILE" | sed 's/#.*//g' | awk -F= '{print $1}' | xargs)
# Export the variables safely
export $(grep -v '^#' "$ENV_FILE" | sed 's/#.*//g' | xargs -d '\n')

# Write the OpenClaw configuration to a JSON file 
cat > '.openclaw-data/openclaw.json' <<EOF
{
  "gateway": {
    "mode": "${OPENCLAW_GATEWAY_MODE}",
    "auth": {
      "mode": "token",
      "token": "${OPENCLAW_GATEWAY_TOKEN}"
    },
    "port": ${OPENCLAW_GATEWAY_PORT},
    "bind": "${OPENCLAW_GATEWAY_BIND}",
    "tailscale": {
      "mode": "off"
    }
  },
  "plugins": {
    "entries": {
      "google": {
        "enabled": true
      }
    }
  },
  "commands": {
    "ownerAllowFrom": [
      "telegram:${TELEGRAM_ALLOWED_IDS}"
    ]
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "${OPENCLAW_PROVIDERS_NAME}/auto@${OPENCLAW_PROVIDERS_NAME}:manual"
      },
      "workspace": "/home/node/.openclaw/workspace",
      "models": {
        "${OPENCLAW_PROVIDERS_NAME}/auto": {}
      }
    },
    "entries": {
      "main": {
        "name": "main",
        "workspace": "/home/node/.openclaw/workspace",
        "agentDir": "/home/node/.openclaw/agents/main/agent",
        "identity": {
          "name": "main"
        }
      }
    }
  },
  "tools": {
    "profile": "full",
    "web": {
      "search": {
        "provider": "gemini",
        "enabled": true
      }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "${OPENCLAW_PROVIDERS_NAME}": {
        "baseUrl": "${OPENCLAW_PROVIDERS_CUSTOM_API_BASE}",
        "api": "openai-completions",
        "auth": "api-key",
        "apiKey": "${OPENCLAW_PROVIDERS_CUSTOM_API_KEY}",
        "models": [
          {
            "id": "auto",
            "name": "auto (Custom Provider)",
            "contextWindow": 128000,
            "maxTokens": 4096,
            "input": [
              "text",
              "image"
            ],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "reasoning": false
          }
        ]
      }
    }
  }
}
EOF

# Authenticate the OpenClaw CLI with the custom provider's API key and start the services
docker compose run -T --rm openclaw-cli bash -c \
"echo '${OPENCLAW_PROVIDERS_CUSTOM_API_KEY}' | openclaw models auth paste-token --provider '${OPENCLAW_PROVIDERS_NAME}'" \
&& docker compose up -d --force-recreate


# Clean up
unset $KEYS