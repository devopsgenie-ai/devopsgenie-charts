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

## Quickstart

```bash
# 1. Create the GHCR pull secret (one-time)
kubectl create namespace devopsgenie
kubectl create secret docker-registry ghcr \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<ghcr-pat> \
  -n devopsgenie

# 2. Create the agent credentials secret
kubectl create secret generic dg-platform-agent \
  --from-literal=DG_AGENT_ID=<your-agent-id> \
  --from-literal=DG_API_KEY=<your-api-key> \
  -n devopsgenie

# 3. Install the chart
helm install dg-agent ./charts/dg-platform-agent \
  --set existingSecret=dg-platform-agent \
  --set ghcr.existingSecret=ghcr \
  --namespace devopsgenie
```

The controller will authenticate with the DevOps Genie platform and begin
accepting tasks.

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
| `controller.port` | Health check port | `8080` |
| `controller.env` | Extra env vars (non-sensitive) | `{}` |
| `controller.resources` | CPU/memory | `100m/128Mi` req, `500m/512Mi` limit |
| **Server** | | |
| `server.wsUrl` | Platform WebSocket URL | `wss://platform.devopsgenie.com/ws/agent` |
| `server.authUrl` | Platform auth URL | `https://platform.devopsgenie.com/api/v1/agents/auth` |
| **Agent Pod** | | |
| `agentPod.image.repository` | Agent pod image | `ghcr.io/devopsgenie-ai/dg-agent-pod` |
| `agentPod.image.tag` | Agent pod tag | `0.1.0` |
| **Sandbox** | | |
| `sandbox.namespace` | Agent pod namespace | Release namespace |
| `sandbox.templateName` | SandboxTemplate name | `dg-agent-pod` |
| `sandbox.maxConcurrentPods` | Max concurrent agent pods | `10` |
| `sandbox.sessionIdleTtlSeconds` | Idle cleanup timeout | `900` |
| **SandboxTemplate** | | |
| `sandboxTemplate.create` | Create the SandboxTemplate CR | `true` |
| `sandboxTemplate.resources` | Agent pod resources | `1cpu/2Gi` req, `2cpu/4Gi` limit |
| `sandboxTemplate.workspaceSize` | Agent workspace volume | `10Gi` |
| `sandboxTemplate.networkPolicy.managed` | Sandbox-managed egress policy | `true` |
| **Warm Pool** | | |
| `sandboxWarmPool.enabled` | Enable SandboxWarmPool | `false` |
| `sandboxWarmPool.replicas` | Pre-warmed pods | `3` |
| **Agent Sandbox** | | |
| `agentSandbox.install` | Install agent-sandbox controller | `true` |
| `agentSandbox.image.repository` | Sandbox controller image | `registry.k8s.io/agent-sandbox/agent-sandbox-controller` |
| `agentSandbox.image.tag` | Sandbox controller version | `v0.2.1` |
| **GHCR** | | |
| `ghcr.existingSecret` | Pre-created dockerconfigjson Secret | `""` |
| `ghcr.externalSecret.enabled` | Use ESO for GHCR pull secret | `false` |
| `ghcr.externalSecret.secretStoreRef.name` | SecretStore name | `""` |
| `ghcr.externalSecret.remoteRef.key` | Remote secret key | `""` |
| **RBAC** | | |
| `rbac.create` | Create ClusterRole for sandbox CRUD | `true` |
| **ServiceAccount** | | |
| `serviceAccount.create` | Create ServiceAccount | `true` |
| `serviceAccount.name` | SA name override | `""` |
| `serviceAccount.annotations` | SA annotations (e.g. IRSA) | `{}` |
| **Credentials** | | |
| `existingSecret` | Secret with `DG_AGENT_ID` + `DG_API_KEY` | `""` |
| `externalSecret.enabled` | Use ESO for agent credentials | `false` |
| `externalSecret.secretStoreRef.name` | SecretStore name | `""` |
| `externalSecret.data` | ESO data mappings | `[]` |
| **Security** | | |
| `podSecurityContext` | Pod security context | `runAsNonRoot, uid 1000` |
| `securityContext` | Container security context | `readOnlyRootFilesystem: true, drop ALL` |
| `networkPolicy.enabled` | Agent pod NetworkPolicy | `true` |

## GHCR Setup

The controller and agent pod images are hosted on private GHCR. You need a
pull secret in the release namespace.

### Option 1: kubectl (quickstart)

```bash
kubectl create secret docker-registry ghcr \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<ghcr-pat> \
  -n devopsgenie
```

Then set `ghcr.existingSecret=ghcr` in your values.

### Option 2: External Secrets Operator

Store the dockerconfigjson in your secret manager, then:

```yaml
ghcr:
  externalSecret:
    enabled: true
    secretStoreRef:
      name: aws-secretsmanager-secrets-store
      kind: ClusterSecretStore
    remoteRef:
      key: prod/ghcr-pull-secret
```

## External Secrets for Agent Credentials

```yaml
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

The controller needs a **ClusterRole** (not namespace Role) because sandbox
CRDs are cluster-scoped. The granted permissions are:

- `agents.x-k8s.io`: sandboxes, sandboxtemplates — CRUD
- `extensions.agents.x-k8s.io`: sandboxclaims, sandboxwarmpools — CRUD
- Core: pods (read), services (read + create), pods/portforward (create)
