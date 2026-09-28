FROM node:24-slim

# ─── Base tools ───────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git gh wget \
    python3 python3-pip python3-venv \
    tmux ripgrep unzip \
    && rm -rf /var/lib/apt/lists/*

# ─── Bun ──────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

# ─── NPM ──────────────────────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code kimaki@latest agy-telegram pm2

# ─── Aider ────────────────────────────────────────────────────────────────────
RUN pip3 install --break-system-packages aider-chat

# ─── Antigravity CLI (agy) ────────────────────────────────────────────────────
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash \
    && ln -sf /root/.local/bin/agy /usr/local/bin/agy

# ─── tgpt (Go binary, no deps) ───────────────────────────────────────────────
# RUN TGPT_VERSION="v3.0.0" && \
#     curl -fsSL "https://github.com/aandrew-me/tgpt/releases/download/${TGPT_VERSION}/tgpt_$(dpkg --print-architecture)_linux" \
#     -o /usr/local/bin/tgpt && chmod +x /usr/local/bin/tgpt
RUN curl -sSL https://raw.githubusercontent.com/aandrew-me/tgpt/main/install | bash -s /usr/local/bin

# ─── MCP servers (installed on-demand via npx, cached in node_modules) ───────
# Pre-install so first agent session doesn't wait on npx download
RUN npm install -g \
    @brave/brave-search-mcp-server \
    && mkdir -p /root/.local/share

RUN curl -fsSL https://opencode.ai/install | bash
ENV PATH="/root/.opencode/bin:$PATH"

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"	

RUN uv tool install git+https://github.com/overwirehq/claude-code-telegram@latest


# Copy your script into the image, then execute it at build time
COPY ./run-config-file.sh /setup.sh
RUN chmod +x /setup.sh && /setup.sh   

# Copy your script into the image, then execute it at build time
COPY ./telegram-agy-claude-bots.sh /bots-setup.sh
RUN chmod +x /bots-setup.sh

WORKDIR /workspace
ENTRYPOINT ["/bots-setup.sh"]