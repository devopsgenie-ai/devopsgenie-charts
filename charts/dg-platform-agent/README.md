# dg-platform-agent

DevOps Genie agent for client clusters. Single `helm install` deploys:

- **DG Controller** — connects to the DevOps Genie platform via WebSocket
- **Agent Sandbox** — kubernetes-sigs/agent-sandbox CRDs + controller (optional)
- **SandboxTemplate** — defines how ephemeral agent pods are created
- **NetworkPolicy** — isolates agent pod traffic

## Prerequisites

- Kubernetes 1.19+
- Helm 3
- Agent credentials (`DG_AGENT_ID` + `DG_API_KEY`) from your DevOps Genie dashboard
- GHCR pull secret for private images (see [GHCR Setup](#ghcr-setup))

## Quick Start

Add the DevOps Genie chart repository:

```bash
helm repo add devopsgenie https://devopsgenie-ai.github.io/devopsgenie-charts
helm repo update
```

Install with credentials supplied directly:

```bash
helm install dg-agent devopsgenie/dg-platform-agent \
  --namespace devopsgenie --create-namespace \
  --set agentId=YOUR_AGENT_ID \
  --set apiKey=YOUR_API_KEY \
  --set imageCredentials.token=ghp_YOUR_GHCR_TOKEN
```

Or, with credentials pre-created as Kubernetes Secrets (recommended for production — see [Secret Management](#secret-management)):

```bash
helm install dg-agent devopsgenie/dg-platform-agent \
  --namespace devopsgenie --create-namespace \
  --set credentials.existingSecret=dg-platform-agent \
  --set imageCredentials.existingSecret=ghcr
```

> **For chart contributors:** The chart can also be installed from a local
> clone with `helm install dg-agent ./charts/dg-platform-agent ...`.

The controller will authenticate with the DevOps Genie platform and begin
accepting tasks.

## Upgrading

Helm intentionally does not update CRDs on `helm upgrade`. When the chart
ships CRD changes (rare, but possible), you must apply CRD updates manually
before running `helm upgrade`:

```bash
kubectl apply -f \
  https://raw.githubusercontent.com/devopsgenie-ai/devopsgenie-charts/main/charts/dg-platform-agent/crds/
```

Then proceed with the upgrade:

```bash
helm repo update
helm upgrade dg-agent devopsgenie/dg-platform-agent --namespace devopsgenie
```

Check the chart's `CHANGELOG` (or release notes) before upgrading across
major versions — they may include breaking changes to values keys or
required migrations.

## Values

| Key | Description | Default |
|-----|-------------|---------|
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override generated resource names | `""` |
| **Controller** | | |
| `controller.image.repository` | Controller image | `ghcr.io/devopsgenie-ai/dg-controller` |
| `controller.image.tag` | Image tag (defaults to `appVersion`) | `""` |
| `controller.image.pullPolicy` | Pull policy | `IfNotPresent` |
| `controller.replicaCount` | Replicas | `1` |
| `controller.env` | Extra env vars (non-sensitive) | `{}` |
| `controller.resources` | CPU/memory | `100m/128Mi` req, `500m/512Mi` limit |
| **Server** | | |
| `server.wsUrl` | Platform WebSocket URL | `wss://platform.devopsgenie.com/ws/agent` |
| `server.authUrl` | Platform auth URL | `https://platform.devopsgenie.com/api/v1/agents/auth` |
| **Agent Pod** | | |
| `agentPod.image.repository` | Agent pod image | `ghcr.io/devopsgenie-ai/dg-agent-pod` |
| `agentPod.image.tag` | Agent pod tag | `0.1.0` |
| `agentPod.existingSecret` | Pre-created Secret for agent pod runtime/VCS env | `""` |
| `agentPod.resources` | Agent pod resources | `1cpu/2Gi` req, `2cpu/4Gi` limit |
| `agentPod.workspaceSize` | Agent workspace volume | `10Gi` |
| `agentPod.commandTimeout` | Max seconds a command may run | `1800` |
| `agentPod.llm.timeoutSeconds` | LiteLLM client request timeout | `300` |
| `agentPod.llm.maxRetries` | LiteLLM client retry count | `2` |
| `agentPod.env` | Extra non-sensitive env vars | `{}` |

`agentPod.llm.timeoutSeconds` must be at least `1`; `agentPod.llm.maxRetries` must be at least `0`. Use these keys instead of setting `AGENT_LLM_TIMEOUT_SECONDS` or `AGENT_LLM_MAX_RETRIES` directly in `agentPod.env`.
| **Sandbox** | | |
| `maxAgents` | Max concurrent agent pods | `10` |
| `sandbox.sessionIdleTtlSeconds` | Idle cleanup timeout | `900` |
| `sandbox.networkPolicy.enabled` | Agent pod NetworkPolicy | `true` |
| **Warm Pool** | | |
| `warmPool.enabled` | Enable SandboxWarmPool | `false` |
| `warmPool.replicas` | Pre-warmed pods | `2` |
| **Agent Sandbox** | | |
| `agentSandbox.install` | Install agent-sandbox controller | `true` |
| `agentSandbox.image.repository` | Sandbox controller image | `registry.k8s.io/agent-sandbox/agent-sandbox-controller` |
| `agentSandbox.image.tag` | Sandbox controller version | `v0.2.1` |
| **GHCR** | | |
| `imageCredentials.token` | GitHub PAT with `read:packages` scope | `""` |
| `imageCredentials.username` | GHCR username | `devopsgenie-ai` |
| `imageCredentials.existingSecret` | Pre-created dockerconfigjson Secret | `""` |
| **ServiceAccount** | | |
| `serviceAccount.create` | Create ServiceAccount | `true` |
| `serviceAccount.name` | SA name override | `""` |
| `serviceAccount.annotations` | SA annotations (e.g. IRSA) | `{}` |
| **Credentials** | | |
| `agentId` | DevOps Genie agent identifier | `""` |
| `apiKey` | DevOps Genie API key | `""` |
| `credentials.existingSecret` | Secret with `DG_AGENT_ID` + `DG_API_KEY` | `""` |
| `credentials.externalSecret.enabled` | Use ESO for agent credentials | `false` |
| `credentials.externalSecret.secretStoreRef.name` | SecretStore name | `""` |
| `credentials.externalSecret.secretStoreRef.kind` | SecretStore kind | `ClusterSecretStore` |
| `credentials.externalSecret.data` | ESO data mappings | `[]` |
| **VCS** | | |
| `vcs.provider` | VCS provider (`github`, `gitlab`, `bitbucket`) | `github` |
| `vcs.token` | VCS access token | `""` |
| `vcs.infrastructureRepoUrl` | HTTPS clone URL for IaC repository | `""` |
| `vcs.infrastructureRepoPath` | IaC repository subdirectory | `""` |
| `vcs.deploymentRepoUrl` | HTTPS clone URL for deployment repository | `""` |
| `vcs.deploymentRepoPath` | Deployment repository subdirectory | `""` |
| `vcs.githubApp.*` | GitHub App auth settings | `""` |

## GHCR Setup

The controller and agent pod images are hosted on private GHCR. You need a
pull secret in the release namespace.

### Option 1: Helm flag (recommended)

Supply the token directly at install time — it is passed as a chart value and
never written to your shell history as a standalone `kubectl` command:

```bash
helm install dg-agent devopsgenie/dg-platform-agent \
  --namespace devopsgenie --create-namespace \
  --set imageCredentials.token=ghp_YOUR_GHCR_TOKEN
```

The chart creates the `dockerconfigjson` Secret from this value automatically.

### Option 2: External Secrets Operator (recommended for production)

Sync the GHCR pull secret from your secret manager using External Secrets
Operator, then reference the resulting Secret:

```yaml
imageCredentials:
  existingSecret: ghcr
```

Create the ESO `ExternalSecret` outside this chart to populate a
`kubernetes.io/dockerconfigjson` Secret named `ghcr` in the release namespace.

### Option 3: kubectl (quick local testing)

```bash
kubectl create secret docker-registry ghcr \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<ghcr-pat> \
  -n devopsgenie
```

> **Note:** This exposes the token in your shell history. Prefer Option 1 or
> Option 2 for shared or production environments.

Then set `imageCredentials.existingSecret=ghcr` in your values.

## External Secrets for Agent Credentials

```yaml
credentials:
  externalSecret:
    enabled: true
    secretStoreRef:
      name: aws-secretsmanager-secrets-store
      kind: ClusterSecretStore
    data:
      - secretKey: DG_AGENT_ID
        remoteRef:
          key: prod/dg-platform-agent
          property: agent_id
      - secretKey: DG_API_KEY
        remoteRef:
          key: prod/dg-platform-agent
          property: api_key
```

## Agent Sandbox

This chart bundles [kubernetes-sigs/agent-sandbox](https://github.com/kubernetes-sigs/agent-sandbox)
v0.2.1 CRDs and controller. If your cluster already has agent-sandbox
installed, disable the bundled controller:

```yaml
agentSandbox:
  install: false
```

The CRDs (in `crds/`) are always installed by Helm regardless of this setting.

## RBAC

This chart creates two distinct RBAC sets:

**1. DG controller (namespace-scoped)**

The DG controller manages Sandbox CRDs (which are namespace-scoped) within
the release namespace. It uses:

- A `Role` with verbs on `sandboxes`, `sandboxclaims`, `sandboxtemplates`,
  and `sandboxwarmpools` from the `agents.x-k8s.io` and
  `extensions.agents.x-k8s.io` API groups.
- A `RoleBinding` to the chart's `ServiceAccount`.

See `templates/controller-rbac.yaml`.

**2. Bundled agent-sandbox controller (cluster-scoped, when `agentSandbox.install=true`)**

The upstream `agent-sandbox` controller (from `kubernetes-sigs/agent-sandbox`)
is bundled because it owns the Sandbox CRD reconciliation across namespaces.
It uses cluster-scoped RBAC:

- `ClusterRole` granting CRD watch/list and Sandbox lifecycle verbs.
- `ClusterRoleBinding` to a dedicated ServiceAccount in
  `agent-sandbox-system`.

If your cluster already has an `agent-sandbox-controller` deployment from
another source, set `agentSandbox.install=false` to skip these resources.

See `templates/agent-sandbox-controller.yaml` and
`templates/agent-sandbox-rbac.yaml`.
