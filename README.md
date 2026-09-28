# Personal Home Lab

Self-hosted Docker services across two devices. Each service is a `docker-compose.yml` with a sample env file, configured via environment variables so it stays portable and safe to share.

## Structure

```
personal-home-lab/
├── machine-1/         Main server (14 services)
│   ├── calibre/         E-book management
│   ├── dockge/          Compose management UI
│   ├── immich/          Photo/video backup
│   ├── llm-cli/         LLM dev container (Claude Code, Aider, agy)
│   ├── n8n/             Workflow automation
│   ├── nextcloud/       File sharing
│   ├── obsidian/        Obsidian sync server
│   ├── openclaw/        AI gateway for chat apps
│   ├── paperless-ngx/   Document management + OCR
│   ├── reading-stack/   Miniflux, Wallabag, Karakeep
│   ├── stirling-pdf/    PDF tools
│   ├── syncthing/       File sync
│   ├── uptime-kuma/     Monitoring
│   └── zotero-webdav/   Zotero + WebDAV
└── machine-2/         Second device (4 services)
    ├── dockge/          Compose management UI
    ├── llm-models/      llama.cpp LLM server (Vulkan GPU)
    ├── syncthing/       File sync
    └── uptime-kuma/     Monitoring
```

## Environment Setup

Every service ships a `.env.example` — copy it to `.env` and fill in your values. Ports and paths have sensible defaults, so most services work with minimal edits.

You have two options for where credentials live:

1. **Split (used in this repo)** — paths, ports, and timezone in the per-service `.env`; credentials (API keys, passwords, tokens) in a central secrets directory **outside** the repo:
   ```yaml
   env_file:
     - ${ENV_BASE:-./../../../secrets}/_${COMPOSE_PROJECT_NAME}.env
   ```
2. **Everything together** — put all variables, credentials included, in the per-service `.env`, and remove (or re-point) the `env_file` lines in that service's compose file.

Option 1 is what makes this repository safe to publish — no credentials are ever committed.

## Quick Start

```bash
# 1. Copy the sample env and edit
cp machine-1/obsidian/.env.example machine-1/obsidian/.env

# 2. Start a service
docker compose -f machine-1/obsidian/docker-compose.yml up -d

# 3. Verify
docker ps
```

Access services at their configured ports — see defaults in each `.env.example`.

## Services

| Machine | Service | Purpose | Default ports |
|---------|---------|---------|---------------|
| 1 | calibre | E-book management (web UI + content server) | 3003, 3004 |
| 1 | dockge | Docker Compose management UI | 5001 |
| 1 | immich | Photo/video backup with ML search | 2283 |
| 1 | llm-cli | Dev container with LLM tools | 3001 (localhost-bound) |
| 1 | n8n | Workflow automation | 5678 |
| 1 | nextcloud | File sharing and collaboration | 8080 |
| 1 | obsidian | Obsidian sync server (web) | 3000 |
| 1 | openclaw | AI gateway for chat apps | 18789, 18790 |
| 1 | paperless-ngx | Document management + OCR | 8000 |
| 1 | reading-stack | Miniflux, Wallabag, Karakeep | 8081, 8082, 3333 |
| 1 | stirling-pdf | PDF manipulation | 3002 |
| 1 | syncthing | File synchronization | host network |
| 1 | uptime-kuma | Service monitoring | 3131 |
| 1 | zotero-webdav | Zotero reference manager + WebDAV | 3005, 9800 |
| 2 | dockge | Docker Compose management UI | 5001 |
| 2 | llm-models | llama.cpp LLM server (Vulkan GPU, multi-model) | 8080 |
| 2 | syncthing | File synchronization | host network |
| 2 | uptime-kuma | Service monitoring | 3131 |

## Security

**Already in place:**
- Credentials live outside the repo (or in gitignored `.env` files) — never committed
- `.gitignore` covers all `.env` files, data dirs, and `PLAN.md`
- Real `.env` files are `chmod 600`
- Container hardening: `no-new-privileges`, `cap_drop` on the gateway, non-root (`PUID`/`PGID` 1000) for obsidian/syncthing, read-only external-library mounts

**When publishing or sharing:**
1. Never commit `.env` files — don't use `git add -f`
2. Scrub personal info from comments before committing (usernames, hostnames, IPs)
3. Git history is permanent — check `git diff --staged` before pushing
4. Keep default credentials changed in any real deployment

## Backup

- **Bind mounts inside the repo** (gitignored): service `config/` and data dirs — back up with `tar`
- **Named Docker volumes**: back up with `docker run --rm -v <volume>:/data ...`
- **External paths** (set via per-service `.env`, e.g. media/models folders): include in your file backup

## Troubleshooting

```bash
# Logs
docker compose -f SERVICE/docker-compose.yml logs -f

# Validate config
docker compose -f SERVICE/docker-compose.yml config
```

- **env_file errors** — create the central secrets file for that service, or remove the `env_file` lines
- **Permission issues** — `sudo chown -R $USER:$USER <data-dir>`
- **Port conflicts** — check the per-service `.env`; obsidian (3000) and dockge (5001) are hardcoded

## License

Each service has its own license. See individual upstream repositories for details.
