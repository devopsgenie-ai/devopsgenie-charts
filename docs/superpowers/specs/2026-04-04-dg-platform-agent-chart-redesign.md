# dg-platform-agent Helm Chart Redesign

**Date:** 2026-04-04
**Status:** Design approved, pending implementation

## Problem

The `dg-platform-agent` chart was originally scaffolded to deploy both the
controller and the WS gateway together. In reality:

- **WS Gateway** runs server-side (DevOps Genie hosted infrastructure).
- **Clients** need a single `helm install` that deploys the controller, the
  agent-sandbox CRD controller, and a SandboxTemplate for agent pods — then
  auto-connects to the DevOps Genie platform.

The current chart is structurally wrong for client-side deployment: it bundles
ws-gateway templates, lacks probes on the controller, has no agent-sandbox
support, no SandboxTemplate, no RBAC for sandbox CRUD, no GHCR pull-secret
generation, and exposes secrets as plain values.

## Goals

1. **Single-command install** — `helm install` brings everything needed.
2. **Auto-connects** — controller authenticates and connects to the server with
   only an API key provided at install time.
3. **Version-pinned agent-sandbox** — ship a tested version of the CRDs +
   controller, with a toggle for clusters that already have it.
4. **Private GHCR images** — controller, agent-sandbox controller (if from
   GHCR), and dynamically-created agent pods all pull from private GHCR.
5. **Production security** — no secrets in values, ESO support, network
   isolation, least-privilege RBAC.

## Architecture

```
Client Cluster                           DevOps Genie Server
┌──────────────────────────────────┐     ┌──────────────────┐
│  dg-platform-agent (Helm)        │     │                  │
│                                  │     │  WS Gateway      │
│  ┌────────────────┐  WebSocket   │     │  (port 5004)     │
│  │  dg-controller ├─────────────────►  │                  │
│  │  (port 8080)   │  outbound    │     │  Platform DB     │
│  └───────┬────────┘              │     │  Redis           │
│          │ creates/destroys      │     └──────────────────┘
│          ▼                       │
│  ┌────────────────┐              │
│  │  SandboxTemplate │            │
│  │  "dg-agent-pod"  │            │
│  └───────┬──────────┘            │
│          │ agent-sandbox CRD     │
│          ▼                       │
│  ┌────────────────┐              │
│  │  Agent Pods     │ (ephemeral) │
│  │  dg-agent-pod   │             │
│  └────────────────┘              │
│                                  │
│  ┌────────────────────┐          │
│  │  agent-sandbox-    │          │
│  │  controller        │ optional │
│  │  (v0.2.1)          │          │
│  └────────────────────┘          │
└──────────────────────────────────┘
```

## Auth Flow

1. Client provides `DG_API_KEY` (and optionally `DG_AGENT_ID`) via a
   Kubernetes Secret (existingSecret, ExternalSecret, or chart-generated).
2. Controller `POST`s `{agent_id, api_key}` to `server.authUrl`.
3. Server hashes the API key, looks up `agent_api_keys` + `agent_registrations`
   in the platform DB, resolves `tenant_id`, returns a JWT.
4. Controller opens a WebSocket to `server.wsUrl`, sends
   `{type: "auth", token, agent_id}` as the first message.
5. Server verifies JWT, registers the agent, replies `auth.ok`.
6. On disconnect/error, controller re-authenticates from scratch (full API key
   flow, not refresh).

## Chart Structure

```
charts/dg-platform-agent/
├── Chart.yaml
├── values.yaml
├── README.md
├── .helmignore
│
├── crds/                                    # Helm auto-installs, never deletes
│   ├── sandboxes.agents.x-k8s.io.yaml
│   ├── sandboxclaims.extensions.agents.x-k8s.io.yaml
│   ├── sandboxtemplates.extensions.agents.x-k8s.io.yaml
│   └── sandboxwarmpools.extensions.agents.x-k8s.io.yaml
│
└── templates/
    ├── _helpers.tpl
    ├── NOTES.txt
    │
    │  # Agent Sandbox controller (conditional: agentSandbox.install)
    ├── agent-sandbox-namespace.yaml
    ├── agent-sandbox-controller.yaml         # Deployment + SA + Service
    ├── agent-sandbox-rbac.yaml               # ClusterRole + ClusterRoleBinding
    │
    │  # DG Controller (always deployed)
    ├── controller-deployment.yaml
    ├── controller-service.yaml
    ├── controller-rbac.yaml                  # ClusterRole: sandbox CRUD, pods, svc
    ├── serviceaccount.yaml
    │
    │  # Agent Pod configuration
    ├── sandbox-template.yaml                 # SandboxTemplate CR
    ├── sandbox-warmpool.yaml                 # Optional SandboxWarmPool CR
    ├── configmap.yaml                        # AGENT_POD_IMAGE / AGENT_POD_TAG
    ├── network-policy.yaml                   # Agent pod ingress/egress isolation
    │
    │  # Secrets
    ├── externalsecret.yaml                   # ESO for agent credentials
    └── externalsecret-ghcr.yaml              # ESO for GHCR pull secret
```

### Templates removed (vs current chart)

All ws-gateway templates are deleted:

- `deployment-ws-gateway.yaml`
- `service-ws-gateway.yaml`
- `ingress.yaml`

These belong to the server-side deployment, not the client chart.

### CRDs directory

Four CRD YAML files extracted from the upstream
`kubernetes-sigs/agent-sandbox` v0.2.1 release manifests:

- `sandboxes.agents.x-k8s.io` — from `core.yaml`
- `sandboxclaims.extensions.agents.x-k8s.io` — from `extensions.yaml`
- `sandboxtemplates.extensions.agents.x-k8s.io` — from `extensions.yaml`
- `sandboxwarmpools.extensions.agents.x-k8s.io` — from `extensions.yaml`

Helm installs CRDs from `crds/` before rendering templates and **never deletes
them on `helm uninstall`** (built-in Helm CRD safety). This is the standard
pattern for charts that ship CRDs.

### Agent-sandbox controller templates

Gated by `agentSandbox.install: true` (default). Extracted from the non-CRD
portions of `core.yaml` + `extensions.yaml`:

- Namespace `agent-sandbox-system` (hardcoded — infrastructure component, like
  `kube-system`).
- Deployment: `agent-sandbox-controller` with configurable image tag.
- ServiceAccount, ClusterRole, ClusterRoleBinding for the sandbox controller.

When `agentSandbox.install: false`, only the CRDs are installed (from `crds/`),
and the client is expected to already have the sandbox controller running.

### Controller deployment

- Image: `ghcr.io/devopsgenie-ai/dg-controller` (private GHCR).
- Probes: `/healthz` (liveness — always 200) and `/readyz` (readiness — 200
  only when WebSocket is connected, else 503).
- Environment variables injected:
  - `DG_WS_URL` from `server.wsUrl`
  - `DG_AUTH_URL` from `server.authUrl`
  - `SANDBOX_NAMESPACE` from `sandbox.namespace` (defaults to release NS)
  - `SANDBOX_TEMPLATE_NAME` from `sandbox.templateName`
  - `MAX_CONCURRENT_PODS` from `sandbox.maxConcurrentPods`
  - `SESSION_IDLE_TTL_SECONDS` from `sandbox.sessionIdleTtlSeconds`
  - `HEALTH_PORT` from `controller.port`
  - Additional non-sensitive env from `controller.env`
- `envFrom`:
  - ConfigMap for `AGENT_POD_IMAGE`, `AGENT_POD_TAG`
  - Secret (from `existingSecret` or ESO target) for `DG_AGENT_ID`,
    `DG_API_KEY`
- `imagePullSecrets` referencing the GHCR Secret.

### Controller RBAC (ClusterRole)

Required because sandbox CRDs are cluster-scoped:

```yaml
rules:
  # Sandbox lifecycle
  - apiGroups: [agents.x-k8s.io]
    resources: [sandboxes, sandboxtemplates]
    verbs: [get, list, watch, create, delete]
  - apiGroups: [extensions.agents.x-k8s.io]
    resources: [sandboxclaims, sandboxwarmpools]
    verbs: [get, list, watch, create, delete]
  # Pod visibility
  - apiGroups: [""]
    resources: [pods]
    verbs: [get, list, watch]
  # Service creation (sandbox SDK)
  - apiGroups: [""]
    resources: [services, services/proxy]
    verbs: [get, list, create]
  # Port-forward (sandbox SDK uses this)
  - apiGroups: [""]
    resources: [pods/portforward]
    verbs: [create]
```

ClusterRoleBinding binds to the chart's ServiceAccount in the release
namespace.

### SandboxTemplate CR

Rendered when `sandboxTemplate.create: true`:

```yaml
apiVersion: extensions.agents.x-k8s.io/v1alpha1
kind: SandboxTemplate
metadata:
  name: {{ .Values.sandbox.templateName }}
spec:
  podTemplate:
    spec:
      imagePullSecrets:
        - name: {{ ghcr secret name }}
      containers:
        - name: agent
          image: {{ agentPod.image.repository }}:{{ agentPod.image.tag }}
          ports:
            - containerPort: 8080
          resources: {{ sandboxTemplate.resources }}
          volumeMounts:
            - name: workspace
              mountPath: /work
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            readOnlyRootFilesystem: false
            capabilities:
              drop: [ALL]
      volumes:
        - name: workspace
          emptyDir:
            sizeLimit: {{ sandboxTemplate.workspaceSize }}
  networkPolicyManagement: {{ Managed | Unmanaged }}
  networkPolicy:
    egress:
      - DNS (UDP/TCP 53)
      - Public HTTPS (443), SSH (22) — excluding RFC1918
      - K8s API server (10.0.0.0/8 on 443, 6443)
```

Key detail: `imagePullSecrets` is set on the SandboxTemplate so dynamically
created agent pods can pull from private GHCR.

### NetworkPolicy

When `networkPolicy.enabled: true`:

- **Ingress** to agent pods: only TCP 8080 from pods labeled `dg-role:
  controller`.
- **Egress** from agent pods: DNS, public HTTPS/SSH, K8s API server.

The controller Deployment gets label `dg-role: controller` to match.

### GHCR Pull Secret

Three modes (mutually exclusive, checked in order):

1. **`ghcr.existingSecret`** — reference a pre-created
   `kubernetes.io/dockerconfigjson` Secret.
2. **`ghcr.externalSecret.enabled`** — ESO syncs from a secret store
   (AWS Secrets Manager, GCP, Vault) into a `dockerconfigjson` Secret.
3. **Neither** — chart generates nothing; user must ensure pull access via
   node-level credentials (ECR IRSA, GCR workload identity, etc.).

The resolved GHCR secret name is used by:
- Controller Deployment `imagePullSecrets`
- SandboxTemplate `imagePullSecrets` (so agent pods can also pull)
- Agent-sandbox controller Deployment `imagePullSecrets` (only if it also
  uses a GHCR image — default is `registry.k8s.io`, which is public)

### Agent Credentials Secret

Two modes:

1. **`existingSecret`** — reference a Secret with keys `DG_AGENT_ID` and
   `DG_API_KEY`.
2. **`externalSecret.enabled`** — ESO syncs from a secret store.

The resolved secret name is mounted as `envFrom` on the controller.

### ExternalSecret templates

**`externalsecret.yaml`** — for agent credentials:

```yaml
# When externalSecret.enabled
apiVersion: external-secrets.io/v1
kind: ExternalSecret
spec:
  secretStoreRef: {{ .Values.externalSecret.secretStoreRef }}
  target:
    name: {{ fullname }}
    creationPolicy: Owner
  data: {{ .Values.externalSecret.data }}
  dataFrom: {{ .Values.externalSecret.dataFrom }}
```

The target name `{{ fullname }}` matches what the `secretName` helper resolves
to when `externalSecret.enabled` is true, so the controller's `envFrom`
references the correct Secret.

**`externalsecret-ghcr.yaml`** — for GHCR pull secret:

```yaml
# When ghcr.externalSecret.enabled
apiVersion: external-secrets.io/v1
kind: ExternalSecret
spec:
  secretStoreRef: {{ .Values.ghcr.externalSecret.secretStoreRef }}
  target:
    name: {{ fullname }}-ghcr
    template:
      type: kubernetes.io/dockerconfigjson
  data:
    - secretKey: .dockerconfigjson
      remoteRef: {{ .Values.ghcr.externalSecret.remoteRef }}
```

## values.yaml Schema

```yaml
# nameOverride overrides the chart name in resource names
nameOverride: ""
# fullnameOverride fully overrides generated resource names
fullnameOverride: ""

# controller is the DG platform controller
controller:
  image:
    repository: ghcr.io/devopsgenie-ai/dg-controller
    tag: ""           # defaults to Chart.appVersion
    pullPolicy: IfNotPresent
  replicaCount: 1
  port: 8080
  env: {}             # non-sensitive env vars only
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  livenessProbe:
    httpGet:
      path: /healthz
      port: http
    initialDelaySeconds: 10
    periodSeconds: 10
  readinessProbe:
    httpGet:
      path: /readyz
      port: http
    initialDelaySeconds: 5
    periodSeconds: 5
  nodeSelector: {}
  tolerations: []
  affinity: {}

# server is the DevOps Genie platform endpoints
server:
  wsUrl: "wss://platform.devopsgenie.com/ws/agent"
  authUrl: "https://platform.devopsgenie.com/api/v1/agents/auth"

# agentPod defines the image for dynamically created agent pods
agentPod:
  image:
    repository: ghcr.io/devopsgenie-ai/dg-agent-pod
    tag: "0.1.0"

# sandbox configures agent sandbox behavior
sandbox:
  namespace: ""                # defaults to release namespace
  templateName: "dg-agent-pod"
  maxConcurrentPods: 10
  sessionIdleTtlSeconds: 900

# sandboxTemplate controls the SandboxTemplate CR
sandboxTemplate:
  create: true
  resources:
    requests:
      memory: "2Gi"
      cpu: "1"
    limits:
      memory: "4Gi"
      cpu: "2"
  workspaceSize: 10Gi
  networkPolicy:
    managed: true

# sandboxWarmPool pre-creates idle sandbox pods
sandboxWarmPool:
  enabled: false
  replicas: 3

# agentSandbox controls the agent-sandbox CRD controller
agentSandbox:
  install: true
  image:
    repository: registry.k8s.io/agent-sandbox/agent-sandbox-controller
    tag: "v0.2.1"

# ghcr configures GHCR pull authentication
ghcr:
  existingSecret: ""
  externalSecret:
    enabled: false
    secretStoreRef:
      name: ""
      kind: ClusterSecretStore
    remoteRef:
      key: ""

# rbac controls RBAC resource creation
rbac:
  create: true

# serviceAccount controls ServiceAccount creation
serviceAccount:
  create: true
  name: ""
  annotations: {}

# existingSecret references a Secret with DG_AGENT_ID, DG_API_KEY
existingSecret: ""

# externalSecret uses ESO for agent credentials
externalSecret:
  enabled: false
  refreshInterval: 1h
  secretStoreRef:
    name: ""
    kind: ClusterSecretStore
  data: []
  dataFrom: []

# podSecurityContext is the pod-level security context
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

# securityContext is the container-level security context
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL

# networkPolicy controls agent pod network isolation
networkPolicy:
  enabled: true
```

## _helpers.tpl Named Templates

Following the helm-chart-dev best practices skill:

- `dg-platform-agent.name` — chart name, truncated to 63 chars
- `dg-platform-agent.fullname` — release-qualified name
- `dg-platform-agent.chart` — chart name + version
- `dg-platform-agent.labels` — common labels (chart, selector, version,
  managed-by)
- `dg-platform-agent.selectorLabels` — stable selector labels (name +
  instance)
- `dg-platform-agent.controller.labels` — adds `component: controller`
- `dg-platform-agent.controller.selectorLabels` — adds `component: controller`
- `dg-platform-agent.serviceAccountName` — resolves to custom name, generated
  name, or `"default"`
- `dg-platform-agent.controller.image` — image:tag with appVersion fallback
- `dg-platform-agent.secretName` — resolves: if `externalSecret.enabled`,
  uses fullname (matches ESO target); else if `existingSecret` set, uses that;
  else empty (no secret mounted)
- `dg-platform-agent.ghcrSecretName` — resolves GHCR ESO target →
  existingSecret → generated name

## NOTES.txt

Post-install output guides the user:

```
DevOps Genie Agent installed successfully!

Controller: {{ fullname }}-controller
Namespace:  {{ .Release.Namespace }}

The controller will authenticate with:
  Auth URL: {{ .Values.server.authUrl }}
  WS URL:   {{ .Values.server.wsUrl }}

Check connection status:
  kubectl get pods -n {{ .Release.Namespace }} -l {{ selectorLabels }}
  kubectl logs -n {{ .Release.Namespace }} -l {{ controllerSelectorLabels }} -f

{{ if .Values.agentSandbox.install }}
Agent Sandbox controller installed in namespace: agent-sandbox-system
{{ end }}

{{ if not (or .Values.existingSecret (and .Values.externalSecret .Values.externalSecret.enabled)) }}
WARNING: No agent credentials configured!
Create a secret with DG_AGENT_ID and DG_API_KEY:
  kubectl create secret generic {{ secretName }} \
    --from-literal=DG_AGENT_ID=<your-agent-id> \
    --from-literal=DG_API_KEY=<your-api-key> \
    -n {{ .Release.Namespace }}
{{ end }}
```

## kube-addon updates (dg-k8s-deployment)

The existing addon at `kube-addons/dg-platform-agent/` needs updates to match
the new chart shape:

### helm-values/dev-us-east-1.yaml

- Remove all ws-gateway values.
- Add `server.wsUrl` / `server.authUrl` pointing to dev server.
- Set `agentSandbox.install: false` (dev cluster already has it via
  `kube-addons/agent-sandbox`).
- Set `ghcr.externalSecret.enabled: true` with
  `secretStoreRef.name: aws-secretsmanager-secrets-store`.
- Set `externalSecret.enabled: true` with credential keys from
  AWS Secrets Manager.
- Set `rbac.create: true`.

### additional-manifests (new)

Add `additional-manifests/base/ghcr-external-secret.yaml` for the GHCR pull
secret (following the reference devops-genie addon pattern), pointing to
`aws-secretsmanager-secrets-store` instead of `gcp-store`.

## CI changes (devopsgenie-charts)

- Update `release-dg-platform-agent.yml` if chart structure changes.
- Update `lint-test.yml` `helm template` invocation to pass required values
  (e.g. `--set existingSecret=test`).
- Add `helm template` tests for:
  - Default install (everything enabled)
  - `agentSandbox.install=false`
  - `externalSecret.enabled=true`
  - `ghcr.existingSecret=my-secret`

## Decisions and rationale

| Decision | Rationale |
|----------|-----------|
| CRDs in `crds/` not templates | Helm never deletes CRDs on uninstall; avoids CRD/CR ordering issues |
| Agent-sandbox controller in templates (conditional) | Non-CRD resources can be toggled and uninstalled cleanly |
| ClusterRole not Role | Sandbox CRDs are cluster-scoped; namespace Role cannot grant access |
| Hardcoded `agent-sandbox-system` namespace | Infrastructure component; consistent with upstream manifests |
| No ws-gateway in chart | Server-side only; different deployment lifecycle |
| `readOnlyRootFilesystem: true` for controller | Controller is a Python WS client, no disk writes needed |
| `readOnlyRootFilesystem: false` for agent pods | Agent pods run Terraform, kubectl, git — need writable filesystem |
| `imagePullSecrets` on SandboxTemplate | Dynamic pods need GHCR auth; controller can't inject pull secrets at runtime |
| Top-level `nameOverride`/`fullnameOverride` | Helm best practice; `global.*` prefix is non-standard |
| No secrets in values.yaml | Helm best practice rule; all secrets via existingSecret or ESO |
