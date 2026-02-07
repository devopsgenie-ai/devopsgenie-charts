# Configuration

DevOps Genie is configured via environment variables.

## Required

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Your Anthropic API key from [console.anthropic.com](https://console.anthropic.com/) |

## Optional – API and server

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | HTTP server port | `8000` |
| `MAX_TIMEOUT` | Request timeout (ms) | `600000` |
| `API_KEY` | Optional API key to protect the server | (none) |
| `CLAUDE_AUTH_METHOD` | Auth method: `cli`, `api_key`, `bedrock`, `vertex` | auto-detect |

## Optional – MCP and integrations

| Variable | Description |
|----------|-------------|
| `GITHUB_PERSONAL_ACCESS_TOKEN` | GitHub PAT for MCP (scopes: repo, read:org as needed) |
| `INFRA_REPOSITORY` | Infra repo for add-infrastructure skill (e.g. `owner/repo`) |
| `INFRA_FOLDER` | Path inside repo (e.g. `path/to/infra/`) |

## Optional – Rate limiting and CORS

| Variable | Description | Default |
|----------|-------------|---------|
| `RATE_LIMIT_ENABLED` | Enable rate limiting | `true` |
| `RATE_LIMIT_CHAT_PER_MINUTE` | Chat requests per minute | `10` |
| `CORS_ORIGINS` | Allowed CORS origins (JSON array) | `["*"]` |

## Kubernetes

- Put non-sensitive values in `values.yaml` under `env`.
- Put secrets in a Kubernetes Secret and set `existingSecret` to that secret name; the chart will use `envFrom` to inject all keys as environment variables.

## Docker Compose

- Copy `.env.example` to `.env` and set variables there. Do not commit `.env`.
