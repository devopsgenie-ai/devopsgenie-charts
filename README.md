# devopsgenie-charts

Helm charts for **DevOps Genie** from [devopsgenie-ai](https://github.com/devopsgenie-ai).

## Repository structure

Charts live in subdirectories under `charts/`; the Helm repo is served from the **gh-pages** branch (GitHub Pages).

```
devopsgenie-charts/
├── charts/
│   ├── devops-genie/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   └── devops-genie-sre-agent/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── README.md
└── (gh-pages branch: index.yaml, *.tgz, index.html)
```

- **Source:** `main` (or default branch) holds chart source under `charts/`.
- **Helm repo:** The **gh-pages** branch holds the built repo: `index.yaml` (catalog of all chart versions), `.tgz` packages, and a simple `index.html` landing page. GitHub Pages serves this branch at the repo root.

## GitHub Pages setup

1. In the repo: **Settings → Pages**.
2. Under **Build and deployment**, choose **Deploy from a branch**.
3. **Branch:** select `gh-pages`, folder **/ (root)**, then **Save**.

The first release workflow run will create the `gh-pages` branch if it does not exist. The Helm repo URL is:

**https://devopsgenie-ai.github.io/devopsgenie-charts/**

## Contents

| Path | Description |
|------|-------------|
| [charts/devops-genie](charts/devops-genie/) | Helm chart for deploying DevOps Genie on Kubernetes |
| [charts/devops-genie-sre-agent](charts/devops-genie-sre-agent/) | Helm chart for SRE troubleshooting and alert investigation |

## Prerequisites

- Kubernetes 1.19+
- Helm 3+
- Access to pull image from `ghcr.io/devopsgenie-ai/devops-genie` (GHCR; see [Image registry](#image-registry))

## Quick start

```bash
helm repo add devopsgenie https://devopsgenie-ai.github.io/devopsgenie-charts/
helm repo update
helm install devops-genie devopsgenie/devops-genie -n devops-genie -f my-values.yaml
```

Create a namespace and a secret with required keys, then install. For private images, create a pull secret (see [Image registry](#image-registry)). Full install steps: [charts/devops-genie/README.md](charts/devops-genie/README.md).

## Chart values reference

| Value | Description | Default |
|-------|-------------|---------|
| **Image** | | |
| `image.repository` | Container image | `ghcr.io/devopsgenie-ai/devops-genie` |
| `image.tag` | Image tag (empty = chart `appVersion`) | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.pullSecrets` | Pull secrets for private registry (e.g. GHCR) | `[]` |
| **Identity** | | |
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full resource names | `""` |
| **Service account** | | |
| `serviceAccount.create` | Create a service account | `true` |
| `serviceAccount.name` | Use existing service account name | `""` |
| **RBAC** | | |
| `rbac.create` | Create ClusterRole + ClusterRoleBinding (read-only cluster access) | `false` |
| `rbac.extraRules` | Extra ClusterRole rules | `[]` |
| **Service** | | |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `8000` |
| **Ingress** | | |
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.className` | Ingress class (e.g. nginx) | `""` |
| `ingress.annotations` | Annotations (auth, proxy, CORS, rate limit, external-dns, etc.) | `{}` |
| `ingress.hosts` | Host and path rules | see values.yaml |
| `ingress.tls` | TLS configuration | `[]` |
| **Environment & secrets** | | |
| `env` | Non-sensitive env vars (key-value map) | `{}` |
| `existingSecret` | Name of existing Secret for envFrom (recommended for API keys) | `""` |
| **External Secrets** | | |
| `externalSecret.enabled` | Sync secrets from external store (AWS, Vault, GCP) via External Secrets Operator | `false` |
| `externalSecret.secretStoreRef` | SecretStore/ClusterSecretStore name and kind | see values.yaml |
| `externalSecret.data` / `dataFrom` | Key mappings or full sync from external store | `[]` |
| **GitHub MCP** | | |
| `mcp.github.useBinary` | Use in-image GitHub MCP binary (no Docker socket) | `false` |
| `dockerSocket.enabled` | Mount host Docker socket for MCP | `false` |
| `dockerSocket.hostPath` | Path to Docker socket on node | `/var/run/docker.sock` |
| **Persistence** | | |
| `persistence.enabled` | Enable PVC for data (e.g. .claude) | `false` |
| `persistence.size` | Size of persistent volume | `1Gi` |
| `persistence.storageClass` | Storage class (empty = default) | `""` |
| **Workload** | | |
| `replicaCount` | Number of replicas | `1` |
| `resources.limits` | CPU/memory limits | `cpu: 1000m`, `memory: 1Gi` |
| `resources.requests` | CPU/memory requests | `cpu: 100m`, `memory: 256Mi` |
| **Placement** | | |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |
| **Security** | | |
| `podSecurityContext` | runAsNonRoot, runAsUser, fsGroup | see values.yaml |
| `securityContext` | allowPrivilegeEscalation, capabilities | see values.yaml |

### Required configuration

- **ANTHROPIC_API_KEY** – set via `existingSecret` or `env` (prefer secret).
- **GITHUB_PERSONAL_ACCESS_TOKEN** – required if using GitHub MCP; set via `existingSecret`.
- **INFRA_REPOSITORY** / **INFRA_FOLDER** – optional; for add-infrastructure skill; set via `env`.

Use `existingSecret` for all sensitive values. Do not put secrets in `values.yaml` or `--set`.

### GitHub MCP: binary vs Docker socket

- **No Docker socket (recommended):** set `mcp.github.useBinary: true` and provide `GITHUB_PERSONAL_ACCESS_TOKEN` in the secret referenced by `existingSecret`.
- **Docker socket:** set `dockerSocket.enabled: true` to mount the host socket (requires Docker/containerd on the node; use only in trusted clusters). Do not set `mcp.github.useBinary` when using the socket.

Details: [charts/devops-genie/README.md](charts/devops-genie/README.md#github-mcp-binary-vs-docker-socket).

## Documentation

Documentation (installation, configuration) is hosted at **https://docs.devopsgenie.ai** (repo: [devops-genie-docs](https://github.com/devopsgenie-ai/devops-genie-docs)).

Helm repo: **https://devopsgenie-ai.github.io/devopsgenie-charts/**

## Image registry

Container images are published to **GitHub Container Registry (GHCR)**:

- `ghcr.io/devopsgenie-ai/devops-genie`

You deploy the chart on your own cluster; the image is hosted in our GHCR. **If the image is private**, your cluster needs credentials to pull it:

1. **Get a token** from DevOps Genie (we use per-client tokens so access can be revoked per deployment). The token must have `read:packages` for GHCR.
2. **Create an image pull secret** in your cluster (e.g. in namespace `devops-genie`):
   ```bash
   kubectl create secret docker-registry ghcr -n devops-genie \
     --docker-server=ghcr.io \
     --docker-username=GITHUB_USER_OR_TOKEN_USERNAME \
     --docker-password=TOKEN_PROVIDED_BY_DEVOPS_GENIE
   ```
3. **Set in values:** `image.pullSecrets: [ghcr]` (or `--set image.pullSecrets[0]=ghcr`).

See [charts/devops-genie/README.md](charts/devops-genie/README.md#pulling-the-image-from-ghcr-private-image) for full details.

## Adding this Helm repo

```bash
helm repo add devopsgenie https://devopsgenie-ai.github.io/devopsgenie-charts/
helm search repo devopsgenie
```

## Publishing (maintainers)

Charts are published via GitHub Actions:

1. **Package:** `helm package charts/<chart>` produces a `.tgz` file.
2. **GitHub Release:** The workflow creates a release (tag `vX.Y.Z`) and attaches the `.tgz`.
3. **Helm repo index:** The workflow checks out (or creates) the **gh-pages** branch, copies the new `.tgz` there, runs `helm repo index . --merge index.yaml --url https://devopsgenie-ai.github.io/devopsgenie-charts`, adds a landing `index.html`, and pushes to **gh-pages**.

Use **Release and publish Helm chart** (chart dropdown) or the per-chart workflows **Release devops-genie chart** / **Release devops-genie-sre-agent chart**. Ensure **Settings → Pages** is set to **Deploy from a branch** → **gh-pages** → **/ (root)**.

## License

See the license applicable to each chart or product.
