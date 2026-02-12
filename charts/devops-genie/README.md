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

### Pulling the image from GHCR (private image)

The container image is hosted in our GitHub Container Registry (`ghcr.io/devopsgenie-ai/devops-genie`). When you deploy the chart on your cluster, your cluster must be able to pull this image.

**If the image is private**, you need an image pull secret:

1. **Get a token from DevOps Genie** (or your account if you have access to the package). We recommend a **per-client token** so access can be revoked per deployment. The token must have `read:packages` scope for GHCR.

2. **Create a Kubernetes pull secret** in the namespace where you will install the chart:

   ```bash
   kubectl create secret docker-registry ghcr -n devops-genie \
     --docker-server=ghcr.io \
     --docker-username=GITHUB_USER_OR_TOKEN_USERNAME \
     --docker-password=TOKEN_PROVIDED_BY_DEVOPS_GENIE
   ```

   Use the token as `--docker-password`. For classic GitHub PATs, `--docker-username` is your GitHub username; for fine-grained tokens, use the username of the token holder.

3. **Tell the chart to use this secret** via values:

   ```yaml
   image:
     repository: ghcr.io/devopsgenie-ai/devops-genie
     pullSecrets: [ghcr]
   ```

   Or with Helm: `--set image.pullSecrets[0]=ghcr`.

If the image is public, you can omit `pullSecrets`.

## Configuration

| Key | Description | Default |
|-----|-------------|---------|
| `image.repository` | Image repository | `ghcr.io/devopsgenie-ai/devops-genie` |
| `image.tag` | Image tag | Chart `appVersion` |
| `image.pullSecrets` | Pull secrets for private registry | `[]` |
| `env` | Env vars (non-sensitive) | `{}` |
| `existingSecret` | Secret name for envFrom (recommended for secrets) | `""` |
| `externalSecret.enabled` | Use External Secrets Operator to sync from external store | `false` |
| `externalSecret.secretStoreRef` | SecretStore/ClusterSecretStore name and kind | see values.yaml |
| `externalSecret.data` / `dataFrom` | Key mappings or full sync | `[]` |
| `mcp.github.useBinary` | Use in-image GitHub MCP binary (no Docker socket) | `false` |
| `dockerSocket.enabled` | Mount host Docker socket (for Docker-based MCP) | `false` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8000` |
| `podSecurityContext` | Pod-level: `runAsNonRoot: true`, `runAsUser: 1000`, `fsGroup: 1000` (matches image `claude_user` UID; do not change unless image is rebuilt with another UID) | see values.yaml |
| `rbac.create` | Create ClusterRole + ClusterRoleBinding (read-only cluster access for agent) | `false` |
| `rbac.extraRules` | Extra ClusterRole rules (list) | `[]` |
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.className` | Ingress class (e.g. nginx) | `""` |
| `ingress.annotations` | Annotations (auth, proxy, CORS, rate limit, external-dns, etc.) | `{}` |
| `ingress.hosts` / `tls` | Host and path rules, TLS | see values.yaml |
| `resources` | CPU/memory limits and requests | see values.yaml |
| `livenessProbe` | Liveness probe spec (httpGet, initialDelaySeconds, periodSeconds, etc.) | `httpGet: /health`, port http, initialDelaySeconds: 30, periodSeconds: 10 |
| `readinessProbe` | Readiness probe spec | `httpGet: /health`, port http, initialDelaySeconds: 5, periodSeconds: 5 |
| `startupProbe` | Startup probe spec; omit or leave empty to disable | unset (no startup probe) |

## Required configuration

- **ANTHROPIC_API_KEY** – set via `existingSecret` or `env`
- **GITHUB_PERSONAL_ACCESS_TOKEN** – if using GitHub MCP; set via `existingSecret`
- **INFRA_REPOSITORY** / **INFRA_FOLDER** – optional; for add-infrastructure skill; set via `env`

Use a Kubernetes Secret for sensitive values and reference it with `existingSecret`. Do not put secrets in `values.yaml` or `--set` in plain text.

### How the secret is created and used

- **Manual:** Create a Secret (e.g. `kubectl create secret generic devops-genie-secret --from-literal=ANTHROPIC_API_KEY=...`) and set `existingSecret: devops-genie-secret`. The deployment uses it via `envFrom`.
- **External Secrets Operator:** Set `externalSecret.enabled: true` and configure `externalSecret.secretStoreRef` and `externalSecret.data` (or `dataFrom`). The [External Secrets](https://external-secrets.io/) controller syncs from your store (AWS Secrets Manager, Vault, GCP, etc.) into a Kubernetes Secret; the deployment uses that secret automatically. Leave `existingSecret` empty when using ExternalSecret.

## External Secrets (optional)

If you use [External Secrets Operator](https://external-secrets.io/), enable it and point to your SecretStore/ClusterSecretStore and key mappings:

```yaml
externalSecret:
  enabled: true
  secretStoreRef:
    name: aws-secrets-manager   # or your ClusterSecretStore name
    kind: ClusterSecretStore    # or SecretStore
  refreshInterval: 1h
  target:
    name: ""   # default: release fullname (e.g. devops-genie-devops-genie)
  data:
    - secretKey: ANTHROPIC_API_KEY
      remoteRef:
        key: prod/devops-genie
        property: anthropic-api-key
    - secretKey: GITHUB_PERSONAL_ACCESS_TOKEN
      remoteRef:
        key: prod/devops-genie
        property: github-token
```

The operator creates a Secret with the target name; the deployment uses it for `envFrom`. Ensure the cluster has the External Secrets controller and a working SecretStore.

## Application env vars (infra_agent)

The app reads [these variables](https://github.com/devopsgenie-ai/infra_agent#configuration) (see infra_agent README and `.env.example`). Map them in the chart as follows:

| App variable | In Helm |
|--------------|--------|
| `PORT` | Set from `service.port` (default `8000`) |
| `ANTHROPIC_API_KEY` | `existingSecret` (recommended) or `env` |
| `API_KEY` | `existingSecret` (recommended) or `env` – optional bearer token to protect the API |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | `existingSecret` or `env` |
| `INFRA_REPOSITORY`, `INFRA_FOLDER` | `env` |
| `CORS_ORIGINS`, `MAX_TIMEOUT`, `MAX_REQUEST_SIZE`, `DEFAULT_MODEL` | `env` |
| `RATE_LIMIT_*`, `CLAUDE_WRAPPER_HOST`, `DEBUG_MODE`, `VERBOSE` | `env` |

`MCP_GITHUB_USE_BINARY` is set automatically when `mcp.github.useBinary: true`.

## RBAC (optional)

If the agent needs to read cluster state (e.g. list pods, get deployments, read ConfigMaps), set `rbac.create: true`. This creates a **ClusterRole** (read-only: get, list, watch on core resources, apps, batch, networking, RBAC, CRDs) and a **ClusterRoleBinding** to the chart’s ServiceAccount. Requires `serviceAccount.create: true`. Add custom rules with `rbac.extraRules` if needed.

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
