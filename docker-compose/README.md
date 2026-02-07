# Docker Compose (EC2 / single host)

Run DevOps Genie with Docker Compose on an EC2 instance or any host with Docker.

## Prerequisites

- Docker and Docker Compose v2
- GitHub PAT with `read:packages` to pull the image from GHCR

## Setup

1. **Login to GHCR** (one-time):

   ```bash
   echo $GITHUB_PAT | docker login ghcr.io -u YOUR_GITHUB_USER --password-stdin
   ```

2. **Create env file**:

   ```bash
   cp .env.example .env
   # Edit .env and set ANTHROPIC_API_KEY (required) and any optional vars
   ```

3. **Start**:

   ```bash
   docker compose up -d
   ```

4. **Verify**:

   ```bash
   curl http://localhost:8000/health
   ```

## Logs and stop

```bash
docker compose logs -f
docker compose down
```

## Notes

- The Compose file uses the pre-built image from `ghcr.io/devopsgenie-ai/devops-genie`. No build step.
- Docker socket is mounted for MCP (e.g. GitHub); omit the volume in `docker-compose.yml` if you do not need it.
- Do not commit `.env`; it may contain secrets.
