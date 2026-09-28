# ─── Antigravity CLI (agy) ────────────────────────────────────────────────────
mkdir -p /root/.gemini/antigravity-cli && cat > /root/.gemini/antigravity-cli/settings.json << 'EOF'
{
  "modelProvider": "gemini"
}
EOF

# ─── Shared MCP config ───────────────────────────────────────────────────
cat > /opt/mcp-shared.json << 'EOF'
{
  "mcpServers": {
    "gemini_search": {
      "command": "npx",
      "args": ["-y", "gemini-search-mcp"],
      "env": { "GEMINI_API_KEY": "${GEMINI_API_KEY}" }
    },
    "duckduckgo": {
      "command": "uvx",
      "args": ["duckduckgo-mcp-server"]
    },
    "brave_search": {
      "command": "npx",
      "args": ["-y", "@brave/brave-search-mcp-server"],
      "env": { "BRAVE_API_KEY": "${BRAVE_API_KEY}" }
    }
  }
}
EOF

# Symlink to both tool locations
mkdir -p /root/.claude /root/.gemini/antigravity-cli \
    && ln -s /opt/mcp-shared.json /root/.claude/mcp.json \
    && ln -s /opt/mcp-shared.json /root/.gemini/antigravity-cli/mcp.json   
    
# ─── Aider MCP config ─────────────────────────────────────────────────────────
cat > /opt/.aider.conf.yml << 'EOF'
model: openai/auto:code
mcp-server:
  - name: gemini_search
    command: npx
    args: ["-y", "gemini-search-mcp"]
  - name: duckduckgo
    command: npx
    args: ["-y", "@nickwongdc/duckduckgo-mcp"]
  - name: brave_search
    command: npx
    args: ["-y", "@brave/search-mcp-server"]
EOF

# ─── tgpt config (points at FreeLLMAPI) ──────────────────────────────────────
mkdir -p /root/.config/tgpt && cat > /root/.config/tgpt/config.json << 'EOF'
{
  "providers": {
    "freellmapi": {
      "type": "openai",
      "apiBase": "http://freellmapi:3001/v1",
      "apiKey": "${FREELLMAPI_TOKEN}",
      "model": "auto:chat"
    }
  },
  "defaultProvider": "freellmapi"
}
EOF

# ─── Shell aliases ────────────────────────────────────────────────────────────
cat >> /root/.bashrc << 'EOF'

# Quick agent shortcuts
alias aider-code='aider --model openai/auto:code'
alias aider-chat='aider --model openai/auto:chat'
alias aider-research='aider --model openai/auto:research'
alias tgpt-chat='tgpt -m auto:chat'
alias tgpt-code='tgpt -m auto:code'

# Caveman mode for tgpt (output compression)
alias tgpt-cave='tgpt -m auto:chat -s "Caveman mode. No filler. No articles. Fragments. Arrows. Shortest correct answer."'
EOF
