# devops-genie Helm chart

Deploy [DevOps Genie](https://github.com/devopsgenie-ai) on Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3+
- Access to pull image from `ghcr.io/devopsgenie-ai/devops-genie` (GitHub Container Registry)

## Add the Helm repo

```bash
helm repo add devopsgenie https://devopsgenie-ai.github.io/devopsgenie-charts/
helm repo update
```

## Install

```bash
# Create namespace
kubectl create namespace devops-genie

# Create a secret with required env vars (do not commit secrets)
kubectl create secret generic devops-genie-secret -n devops-genie \
  --from-literal=ANTHROPIC_API_KEY='your-key' \
  --from-literal=GITHUB_PERSONAL_ACCESS_TOKEN='your-gh-token'

# Install with existing secret
helm install devops-genie devopsgenie/devops-genie -n devops-genie \
  --set existingSecret=devops-genie-secret \
  --set image.pullSecrets[0]=ghcr
```

For GHCR, create a pull secret:

```bash
kubectl create secret docker-registry ghcr -n devops-genie \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USER \
  --docker-password=YOUR_GITHUB_PAT
```

## Configuration

| Key | Description | Default |
|-----|-------------|---------|
| `image.repository` | Image repository | `ghcr.io/devopsgenie-ai/devops-genie` |
| `image.tag` | Image tag | Chart `appVersion` |
| `image.pullSecrets` | Pull secrets for private registry | `[]` |
| `env` | Env vars (non-sensitive) | `{}` |
| `existingSecret` | Secret name for envFrom (recommended for secrets) | `""` |
| `mcp.github.useBinary` | Use in-image GitHub MCP binary (no Docker socket) | `false` |
| `dockerSocket.enabled` | Mount host Docker socket (for Docker-based MCP) | `false` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8000` |
| `ingress.enabled` | Enable Ingress | `false` |
| `resources` | CPU/memory limits and requests | see values.yaml |

## Required configuration

- **ANTHROPIC_API_KEY** – set via `existingSecret` or `env`
- **GITHUB_PERSONAL_ACCESS_TOKEN** – if using GitHub MCP; set via secret
- **INFRA_REPOSITORY** / **INFRA_FOLDER** – for add-infrastructure skill; can be set via `env`

Use a Kubernetes Secret for sensitive values and reference it with `existingSecret`. Do not put secrets in `values.yaml` or `--set` in plain text.

## GitHub MCP: binary vs Docker socket

**Option A – No Docker socket (recommended for locked-down clusters)**  
Use the in-image GitHub MCP binary. Set `mcp.github.useBinary: true` and provide `GITHUB_PERSONAL_ACCESS_TOKEN` via `existingSecret`:

```yaml
mcp:
  github:
    useBinary: true
existingSecret: devops-genie-secret  # must contain GITHUB_PERSONAL_ACCESS_TOKEN
```

**Option B – Docker socket**  
To run GitHub MCP via Docker (sibling containers on the node), mount the host Docker socket:

```yaml
dockerSocket:
  enabled: true
  hostPath: /var/run/docker.sock
```

Ensure nodes have Docker or containerd at that path. This has security implications; use only in trusted clusters. Do not set `mcp.github.useBinary` when using the socket.

## Uninstall

```bash
helm uninstall devops-genie -n devops-genie
kubectl delete secret devops-genie-secret -n devops-genie
kubectl delete secret ghcr -n devops-genie
```
