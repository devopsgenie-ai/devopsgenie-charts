# dg-platform-agent Chart Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the `dg-platform-agent` Helm chart as a client-side installer that deploys the DG controller, agent-sandbox CRDs + controller, SandboxTemplate, and auto-connects to the DevOps Genie platform.

**Architecture:** Single umbrella Helm chart with CRDs in `crds/`, conditional agent-sandbox controller in templates, always-on DG controller with probes and RBAC, SandboxTemplate CR with GHCR pull secrets, and ESO integration for credentials. WS gateway templates removed (server-side only).

**Tech Stack:** Helm 3, Kubernetes 1.19+, agent-sandbox v0.2.1 CRDs, External Secrets Operator (optional), Kustomize (kube-addon overlays)

**Spec:** `docs/superpowers/specs/2026-04-04-dg-platform-agent-chart-redesign.md`

---

## File Structure

### Files to delete

- `charts/dg-platform-agent/templates/deployment-ws-gateway.yaml`
- `charts/dg-platform-agent/templates/service-ws-gateway.yaml`
- `charts/dg-platform-agent/templates/ingress.yaml`

### Files to create

| File | Responsibility |
|------|---------------|
| `charts/dg-platform-agent/crds/sandboxes.agents.x-k8s.io.yaml` | Sandbox CRD (from agent-sandbox core.yaml) |
| `charts/dg-platform-agent/crds/sandboxclaims.extensions.agents.x-k8s.io.yaml` | SandboxClaim CRD (from extensions.yaml) |
| `charts/dg-platform-agent/crds/sandboxtemplates.extensions.agents.x-k8s.io.yaml` | SandboxTemplate CRD (from extensions.yaml) |
| `charts/dg-platform-agent/crds/sandboxwarmpools.extensions.agents.x-k8s.io.yaml` | SandboxWarmPool CRD (from extensions.yaml) |
| `charts/dg-platform-agent/templates/agent-sandbox-namespace.yaml` | NS for sandbox controller |
| `charts/dg-platform-agent/templates/agent-sandbox-controller.yaml` | Deployment + SA + Service |
| `charts/dg-platform-agent/templates/agent-sandbox-rbac.yaml` | ClusterRole + ClusterRoleBinding |
| `charts/dg-platform-agent/templates/controller-rbac.yaml` | ClusterRole for DG controller sandbox CRUD |
| `charts/dg-platform-agent/templates/sandbox-template.yaml` | SandboxTemplate CR |
| `charts/dg-platform-agent/templates/sandbox-warmpool.yaml` | Optional SandboxWarmPool CR |
| `charts/dg-platform-agent/templates/network-policy.yaml` | Agent pod isolation |
| `charts/dg-platform-agent/templates/externalsecret-ghcr.yaml` | ESO for GHCR pull secret |
| `charts/dg-platform-agent/README.md` | Chart documentation |

### Files to rewrite

| File | What changes |
|------|-------------|
| `charts/dg-platform-agent/Chart.yaml` | Bump version, update description |
| `charts/dg-platform-agent/values.yaml` | Complete rewrite to new schema |
| `charts/dg-platform-agent/templates/_helpers.tpl` | Remove ws-gateway helpers, add new helpers |
| `charts/dg-platform-agent/templates/deployment-controller.yaml` | Rename, add probes, new env vars, remove ws-gateway refs |
| `charts/dg-platform-agent/templates/service-controller.yaml` | Minor label updates |
| `charts/dg-platform-agent/templates/serviceaccount.yaml` | Add annotations support, fix fallback |
| `charts/dg-platform-agent/templates/configmap.yaml` | Same shape, updated labels |
| `charts/dg-platform-agent/templates/externalsecret.yaml` | Update target name logic |
| `charts/dg-platform-agent/templates/rbac.yaml` | Delete (replaced by controller-rbac.yaml) |
| `charts/dg-platform-agent/templates/NOTES.txt` | Rewrite for controller-only experience |

### kube-addon files to update

| File | What changes |
|------|-------------|
| `/dg-k8s-deployment/kube-addons/dg-platform-agent/helm-values/dev-us-east-1.yaml` | Rewrite for new values schema |
| `/dg-k8s-deployment/kube-addons/dg-platform-agent/base/application.yaml` | Add third source for additional-manifests |

### kube-addon files to create

| File | Responsibility |
|------|---------------|
| `/dg-k8s-deployment/kube-addons/dg-platform-agent/additional-manifests/base/kustomization.yaml` | Include GHCR ExternalSecret |
| `/dg-k8s-deployment/kube-addons/dg-platform-agent/additional-manifests/base/ghcr-external-secret.yaml` | GHCR pull secret via AWS Secrets Manager |
| `/dg-k8s-deployment/kube-addons/dg-platform-agent/additional-manifests/overlays/dev-us-east-1/kustomization.yaml` | Cluster overlay |

---

## Task 1: Extract CRDs from agent-sandbox manifests

**Files:**
- Source: `/dg-k8s-deployment/kube-addons/agent-sandbox/manifests/core.yaml`
- Source: `/dg-k8s-deployment/kube-addons/agent-sandbox/manifests/extensions.yaml`
- Create: `charts/dg-platform-agent/crds/sandboxes.agents.x-k8s.io.yaml`
- Create: `charts/dg-platform-agent/crds/sandboxclaims.extensions.agents.x-k8s.io.yaml`
- Create: `charts/dg-platform-agent/crds/sandboxtemplates.extensions.agents.x-k8s.io.yaml`
- Create: `charts/dg-platform-agent/crds/sandboxwarmpools.extensions.agents.x-k8s.io.yaml`

- [ ] **Step 1: Extract `sandboxes` CRD from core.yaml**

The `core.yaml` file contains one CRD (`sandboxes.agents.x-k8s.io`) starting at `kind: CustomResourceDefinition` and running ~4000 lines, followed by a Deployment. Extract only the CRD document (the YAML document starting with `apiVersion: apiextensions.k8s.io/v1` and `name: sandboxes.agents.x-k8s.io`).

```bash
# In /dg-k8s-deployment
# Find the CRD boundaries in core.yaml:
grep -n "^kind:" kube-addons/agent-sandbox/manifests/core.yaml
# Expected: lines showing Namespace, ServiceAccount, ClusterRoleBinding, Service, CustomResourceDefinition, ClusterRole, Deployment
```

Use a script or manual extraction to isolate the CRD YAML document. Save to `charts/dg-platform-agent/crds/sandboxes.agents.x-k8s.io.yaml`.

- [ ] **Step 2: Extract 3 CRDs from extensions.yaml**

The `extensions.yaml` contains three CRDs followed by a Deployment:
- `sandboxclaims.extensions.agents.x-k8s.io` (~line 1)
- `sandboxtemplates.extensions.agents.x-k8s.io` (~line 106)
- `sandboxwarmpools.extensions.agents.x-k8s.io` (~line 4129)

```bash
grep -n "^kind:" kube-addons/agent-sandbox/manifests/extensions.yaml
# Expected: CustomResourceDefinition (×3), ClusterRole, Deployment, ClusterRoleBinding
```

Extract each CRD into its own file:
- `crds/sandboxclaims.extensions.agents.x-k8s.io.yaml`
- `crds/sandboxtemplates.extensions.agents.x-k8s.io.yaml`
- `crds/sandboxwarmpools.extensions.agents.x-k8s.io.yaml`

- [ ] **Step 3: Verify CRD files parse**

```bash
cd /devopsgenie-charts
for f in charts/dg-platform-agent/crds/*.yaml; do
  echo "--- $f ---"
  head -5 "$f"
  echo ""
done
```

Each file should start with `apiVersion: apiextensions.k8s.io/v1` and `kind: CustomResourceDefinition`.

- [ ] **Step 4: Commit**

```bash
cd /devopsgenie-charts
git add charts/dg-platform-agent/crds/
git commit -m "feat(dg-platform-agent): extract agent-sandbox v0.2.1 CRDs into crds/"
```

---

## Task 2: Delete ws-gateway templates and rewrite values.yaml + Chart.yaml

**Files:**
- Delete: `charts/dg-platform-agent/templates/deployment-ws-gateway.yaml`
- Delete: `charts/dg-platform-agent/templates/service-ws-gateway.yaml`
- Delete: `charts/dg-platform-agent/templates/ingress.yaml`
- Rewrite: `charts/dg-platform-agent/values.yaml`
- Modify: `charts/dg-platform-agent/Chart.yaml`

- [ ] **Step 1: Delete ws-gateway templates**

```bash
cd /devopsgenie-charts
rm charts/dg-platform-agent/templates/deployment-ws-gateway.yaml
rm charts/dg-platform-agent/templates/service-ws-gateway.yaml
rm charts/dg-platform-agent/templates/ingress.yaml
```

- [ ] **Step 2: Rewrite values.yaml**

Replace the entire file with the new schema from the spec. Every value must have a comment starting with its key name. Key sections:

```yaml
# nameOverride overrides the chart name in resource names
nameOverride: ""
# fullnameOverride fully overrides generated resource names
fullnameOverride: ""

# controller is the DG platform controller that connects to DevOps Genie server
controller:
  image:
    # controller.image.repository is the container image repository
    repository: ghcr.io/devopsgenie-ai/dg-controller
    # controller.image.tag overrides the image tag (defaults to Chart appVersion)
    tag: ""
    # controller.image.pullPolicy is the Kubernetes image pull policy
    pullPolicy: IfNotPresent
  # controller.replicaCount is the number of controller pod replicas
  replicaCount: 1
  # controller.port is the health check HTTP port
  port: 8080
  # controller.env is additional environment variables (non-sensitive only)
  env: {}
  # controller.resources defines CPU/memory requests and limits
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  # controller.livenessProbe checks if the controller process is alive
  livenessProbe:
    httpGet:
      path: /healthz
      port: http
    initialDelaySeconds: 10
    periodSeconds: 10
  # controller.readinessProbe checks if the controller is connected to the server
  readinessProbe:
    httpGet:
      path: /readyz
      port: http
    initialDelaySeconds: 5
    periodSeconds: 5
  nodeSelector: {}
  tolerations: []
  affinity: {}

# server is the DevOps Genie platform server endpoints
server:
  # server.wsUrl is the WebSocket URL the controller connects to
  wsUrl: "wss://platform.devopsgenie.com/ws/agent"
  # server.authUrl is the authentication endpoint
  authUrl: "https://platform.devopsgenie.com/api/v1/agents/auth"

# agentPod defines the agent pod image spawned inside sandboxes
agentPod:
  image:
    # agentPod.image.repository is the agent pod container image
    repository: ghcr.io/devopsgenie-ai/dg-agent-pod
    # agentPod.image.tag is the agent pod image tag
    tag: "0.1.0"

# sandbox configures how the controller creates agent sandboxes
sandbox:
  # sandbox.namespace is the namespace where agent pods are created (defaults to release namespace)
  namespace: ""
  # sandbox.templateName is the SandboxTemplate CR name
  templateName: "dg-agent-pod"
  # sandbox.maxConcurrentPods limits simultaneous agent pods
  maxConcurrentPods: 10
  # sandbox.sessionIdleTtlSeconds is idle time before pod cleanup
  sessionIdleTtlSeconds: 900

# sandboxTemplate controls the SandboxTemplate CR rendered by this chart
sandboxTemplate:
  # sandboxTemplate.create enables rendering the SandboxTemplate CR
  create: true
  # sandboxTemplate.resources for agent pod containers
  resources:
    requests:
      memory: "2Gi"
      cpu: "1"
    limits:
      memory: "4Gi"
      cpu: "2"
  # sandboxTemplate.workspaceSize is the emptyDir size for /work
  workspaceSize: 10Gi
  # sandboxTemplate.networkPolicy controls agent pod network isolation
  networkPolicy:
    # sandboxTemplate.networkPolicy.managed enables sandbox-managed egress policy
    managed: true

# sandboxWarmPool pre-creates idle sandbox pods for faster task start
sandboxWarmPool:
  # sandboxWarmPool.enabled enables the SandboxWarmPool CR
  enabled: false
  # sandboxWarmPool.replicas is the number of warm pods to maintain
  replicas: 3

# agentSandbox controls installation of the agent-sandbox controller (k8s-sigs)
agentSandbox:
  # agentSandbox.install enables deploying the agent-sandbox CRD controller
  install: true
  image:
    # agentSandbox.image.repository is the upstream sandbox controller image
    repository: registry.k8s.io/agent-sandbox/agent-sandbox-controller
    # agentSandbox.image.tag pins the agent-sandbox controller version
    tag: "v0.2.1"

# ghcr configures GHCR image pull authentication
ghcr:
  # ghcr.existingSecret references a pre-created dockerconfigjson Secret
  existingSecret: ""
  # ghcr.externalSecret uses ESO to sync the pull secret from a secret store
  externalSecret:
    enabled: false
    secretStoreRef:
      name: ""
      kind: ClusterSecretStore
    remoteRef:
      key: ""

# rbac controls RBAC resource creation
rbac:
  # rbac.create enables ClusterRole + ClusterRoleBinding for sandbox management
  create: true

# serviceAccount controls ServiceAccount creation
serviceAccount:
  # serviceAccount.create enables ServiceAccount creation
  create: true
  # serviceAccount.name overrides the ServiceAccount name
  name: ""
  # serviceAccount.annotations adds annotations (e.g. IRSA role ARN)
  annotations: {}

# existingSecret references a Secret containing DG_AGENT_ID, DG_API_KEY
existingSecret: ""

# externalSecret uses ESO to sync agent credentials from a secret store
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

# networkPolicy controls the NetworkPolicy for agent pod isolation
networkPolicy:
  # networkPolicy.enabled creates a NetworkPolicy restricting agent pod traffic
  enabled: true
```

- [ ] **Step 3: Update Chart.yaml**

Bump `version` to `0.2.0` and update `description`:

```yaml
apiVersion: v2
name: dg-platform-agent
description: >-
  DevOps Genie agent for client clusters — deploys the DG controller,
  agent-sandbox CRDs + controller, and SandboxTemplate. Single helm install
  auto-connects to the DevOps Genie platform.
type: application
version: 0.2.0
appVersion: "0.1.0"
kubeVersion: ">=1.19.0-0"
keywords:
  - devops-genie
  - platform-agent
  - controller
  - agent-sandbox
  - ai
home: https://github.com/devopsgenie-ai/devopsgenie-charts
sources:
  - https://github.com/devopsgenie-ai/devopsgenie-charts
maintainers:
  - name: DevOps Genie
    url: https://github.com/devopsgenie-ai
```

- [ ] **Step 4: Commit**

```bash
git add -A charts/dg-platform-agent/
git commit -m "feat(dg-platform-agent): remove ws-gateway, rewrite values.yaml and Chart.yaml

BREAKING: ws-gateway templates removed (server-side only).
New values schema for client-side controller deployment."
```

---

## Task 3: Rewrite _helpers.tpl

**Files:**
- Rewrite: `charts/dg-platform-agent/templates/_helpers.tpl`

- [ ] **Step 1: Write new _helpers.tpl**

Replace entirely. Named templates needed (follow helm-chart-dev skill pattern):

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "dg-platform-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "dg-platform-agent.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "dg-platform-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dg-platform-agent.labels" -}}
helm.sh/chart: {{ include "dg-platform-agent.chart" . }}
{{ include "dg-platform-agent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels (stable — used in matchLabels)
*/}}
{{- define "dg-platform-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dg-platform-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Controller labels
*/}}
{{- define "dg-platform-agent.controller.labels" -}}
{{ include "dg-platform-agent.labels" . }}
app.kubernetes.io/component: controller
{{- end }}

{{/*
Controller selector labels
*/}}
{{- define "dg-platform-agent.controller.selectorLabels" -}}
{{ include "dg-platform-agent.selectorLabels" . }}
app.kubernetes.io/component: controller
{{- end }}

{{/*
ServiceAccount name — resolves to custom name, generated name, or "default"
*/}}
{{- define "dg-platform-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "dg-platform-agent.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Controller image
*/}}
{{- define "dg-platform-agent.controller.image" -}}
{{- $tag := .Values.controller.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" .Values.controller.image.repository $tag }}
{{- end }}

{{/*
Secret name for agent credentials (DG_AGENT_ID, DG_API_KEY).
Resolves: externalSecret target → existingSecret → empty.
*/}}
{{- define "dg-platform-agent.secretName" -}}
{{- if .Values.externalSecret.enabled -}}
{{- include "dg-platform-agent.fullname" . }}
{{- else -}}
{{- .Values.existingSecret }}
{{- end }}
{{- end }}

{{/*
GHCR pull secret name.
Resolves: ghcr.externalSecret target → ghcr.existingSecret → empty.
*/}}
{{- define "dg-platform-agent.ghcrSecretName" -}}
{{- if .Values.ghcr.externalSecret.enabled -}}
{{- printf "%s-ghcr" (include "dg-platform-agent.fullname" .) }}
{{- else -}}
{{- .Values.ghcr.existingSecret }}
{{- end }}
{{- end }}

{{/*
imagePullSecrets list — includes GHCR secret if configured.
*/}}
{{- define "dg-platform-agent.imagePullSecrets" -}}
{{- $ghcrName := include "dg-platform-agent.ghcrSecretName" . -}}
{{- if $ghcrName }}
imagePullSecrets:
  - name: {{ $ghcrName }}
{{- end }}
{{- end }}

{{/*
Sandbox namespace — defaults to release namespace.
*/}}
{{- define "dg-platform-agent.sandboxNamespace" -}}
{{- .Values.sandbox.namespace | default .Release.Namespace }}
{{- end }}
```

- [ ] **Step 2: Verify template renders**

```bash
cd /devopsgenie-charts
helm template test charts/dg-platform-agent --set existingSecret=test 2>&1 | head -20
```

This will fail because templates reference values that don't exist yet — that's expected. Verify it doesn't fail on `_helpers.tpl` parse errors.

- [ ] **Step 3: Commit**

```bash
git add charts/dg-platform-agent/templates/_helpers.tpl
git commit -m "refactor(dg-platform-agent): rewrite _helpers.tpl for controller-only chart"
```

---

## Task 4: Rewrite controller deployment + service + serviceaccount

**Files:**
- Rewrite: `charts/dg-platform-agent/templates/deployment-controller.yaml` → rename to `controller-deployment.yaml`
- Rewrite: `charts/dg-platform-agent/templates/service-controller.yaml` → rename to `controller-service.yaml`
- Rewrite: `charts/dg-platform-agent/templates/serviceaccount.yaml`
- Rewrite: `charts/dg-platform-agent/templates/configmap.yaml`

- [ ] **Step 1: Delete old files, create controller-deployment.yaml**

```bash
rm charts/dg-platform-agent/templates/deployment-controller.yaml
rm charts/dg-platform-agent/templates/service-controller.yaml
```

Create `charts/dg-platform-agent/templates/controller-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "dg-platform-agent.fullname" . }}-controller
  labels:
    {{- include "dg-platform-agent.controller.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.controller.replicaCount }}
  selector:
    matchLabels:
      {{- include "dg-platform-agent.controller.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
      labels:
        {{- include "dg-platform-agent.controller.selectorLabels" . | nindent 8 }}
        dg-role: controller
    spec:
      {{- include "dg-platform-agent.imagePullSecrets" . | nindent 6 }}
      serviceAccountName: {{ include "dg-platform-agent.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: controller
          image: {{ include "dg-platform-agent.controller.image" . }}
          imagePullPolicy: {{ .Values.controller.image.pullPolicy }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          ports:
            - name: http
              containerPort: {{ .Values.controller.port }}
              protocol: TCP
          {{- with .Values.controller.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.controller.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          env:
            - name: DG_WS_URL
              value: {{ .Values.server.wsUrl | quote }}
            - name: DG_AUTH_URL
              value: {{ .Values.server.authUrl | quote }}
            - name: SANDBOX_NAMESPACE
              value: {{ include "dg-platform-agent.sandboxNamespace" . | quote }}
            - name: SANDBOX_TEMPLATE_NAME
              value: {{ .Values.sandbox.templateName | quote }}
            - name: MAX_CONCURRENT_PODS
              value: {{ .Values.sandbox.maxConcurrentPods | quote }}
            - name: SESSION_IDLE_TTL_SECONDS
              value: {{ .Values.sandbox.sessionIdleTtlSeconds | quote }}
            - name: HEALTH_PORT
              value: {{ .Values.controller.port | quote }}
            {{- range $k, $v := .Values.controller.env }}
            - name: {{ $k }}
              value: {{ $v | quote }}
            {{- end }}
          envFrom:
            - configMapRef:
                name: {{ include "dg-platform-agent.fullname" . }}-agent-pod-config
            {{- $secretName := include "dg-platform-agent.secretName" . }}
            {{- if $secretName }}
            - secretRef:
                name: {{ $secretName }}
            {{- end }}
          resources:
            {{- toYaml .Values.controller.resources | nindent 12 }}
      {{- with .Values.controller.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.controller.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.controller.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

- [ ] **Step 2: Create controller-service.yaml**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "dg-platform-agent.fullname" . }}-controller
  labels:
    {{- include "dg-platform-agent.controller.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  ports:
    - port: {{ .Values.controller.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "dg-platform-agent.controller.selectorLabels" . | nindent 4 }}
```

- [ ] **Step 3: Rewrite serviceaccount.yaml**

```yaml
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "dg-platform-agent.serviceAccountName" . }}
  labels:
    {{- include "dg-platform-agent.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

- [ ] **Step 4: Update configmap.yaml (labels only)**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "dg-platform-agent.fullname" . }}-agent-pod-config
  labels:
    {{- include "dg-platform-agent.labels" . | nindent 4 }}
data:
  AGENT_POD_IMAGE: {{ .Values.agentPod.image.repository | quote }}
  AGENT_POD_TAG: {{ .Values.agentPod.image.tag | quote }}
```

- [ ] **Step 5: Verify template renders**

```bash
helm template test charts/dg-platform-agent --set existingSecret=test 2>&1 | head -80
```

- [ ] **Step 6: Commit**

```bash
git add -A charts/dg-platform-agent/templates/
git commit -m "feat(dg-platform-agent): rewrite controller deployment, service, SA, configmap

Add probes (/healthz, /readyz), server URL env vars, sandbox config env,
envFrom for credentials secret, imagePullSecrets from GHCR helper."
```

---

## Task 5: Add controller RBAC (ClusterRole for sandbox CRUD)

**Files:**
- Delete: `charts/dg-platform-agent/templates/rbac.yaml`
- Create: `charts/dg-platform-agent/templates/controller-rbac.yaml`

- [ ] **Step 1: Delete old rbac.yaml and create controller-rbac.yaml**

```bash
rm charts/dg-platform-agent/templates/rbac.yaml
```

Create `charts/dg-platform-agent/templates/controller-rbac.yaml`:

```yaml
{{- if .Values.rbac.create -}}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ include "dg-platform-agent.fullname" . }}-controller
  labels:
    {{- include "dg-platform-agent.controller.labels" . | nindent 4 }}
rules:
  - apiGroups: [agents.x-k8s.io]
    resources: [sandboxes, sandboxtemplates]
    verbs: [get, list, watch, create, delete]
  - apiGroups: [extensions.agents.x-k8s.io]
    resources: [sandboxclaims, sandboxwarmpools]
    verbs: [get, list, watch, create, delete]
  - apiGroups: [""]
    resources: [pods]
    verbs: [get, list, watch]
  - apiGroups: [""]
    resources: [services, services/proxy]
    verbs: [get, list, create]
  - apiGroups: [""]
    resources: [pods/portforward]
    verbs: [create]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ include "dg-platform-agent.fullname" . }}-controller
  labels:
    {{- include "dg-platform-agent.controller.labels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ include "dg-platform-agent.fullname" . }}-controller
subjects:
  - kind: ServiceAccount
    name: {{ include "dg-platform-agent.serviceAccountName" . }}
    namespace: {{ .Release.Namespace }}
{{- end }}
```

- [ ] **Step 2: Verify render**

```bash
helm template test charts/dg-platform-agent --set existingSecret=test | grep -A 30 "kind: ClusterRole"
```

- [ ] **Step 3: Commit**

```bash
git add charts/dg-platform-agent/templates/controller-rbac.yaml
git rm charts/dg-platform-agent/templates/rbac.yaml
git commit -m "feat(dg-platform-agent): add ClusterRole for sandbox CRUD, remove old namespace Role"
```

---

## Task 6: Add agent-sandbox controller templates (conditional)

**Files:**
- Create: `charts/dg-platform-agent/templates/agent-sandbox-namespace.yaml`
- Create: `charts/dg-platform-agent/templates/agent-sandbox-controller.yaml`
- Create: `charts/dg-platform-agent/templates/agent-sandbox-rbac.yaml`

Extract the non-CRD resources from `core.yaml` and `extensions.yaml` (Namespace, ServiceAccount, Service, Deployment, ClusterRole, ClusterRoleBinding) and template them with `{{- if .Values.agentSandbox.install }}` gates and configurable image tag.

- [ ] **Step 1: Create agent-sandbox-namespace.yaml**

```yaml
{{- if .Values.agentSandbox.install -}}
apiVersion: v1
kind: Namespace
metadata:
  name: agent-sandbox-system
  labels:
    {{- include "dg-platform-agent.labels" . | nindent 4 }}
{{- end }}
```

- [ ] **Step 2: Create agent-sandbox-controller.yaml**

Extract from `core.yaml` + `extensions.yaml` the ServiceAccount, Service, and both Deployments. The upstream has two deployments: `agent-sandbox-controller` (from core) and `agent-sandbox-controller-extensions` (from extensions). Combine into one file, gated by `agentSandbox.install`. Template the image tag with `{{ .Values.agentSandbox.image.repository }}:{{ .Values.agentSandbox.image.tag }}`.

Note: the upstream Deployments reference `registry.k8s.io/agent-sandbox/agent-sandbox-controller:v0.2.1` for both. Template this so users can override.

- [ ] **Step 3: Create agent-sandbox-rbac.yaml**

Extract ClusterRole + ClusterRoleBinding from both `core.yaml` and `extensions.yaml`. Gate with `agentSandbox.install`.

- [ ] **Step 4: Verify render with agentSandbox.install=true**

```bash
helm template test charts/dg-platform-agent --set existingSecret=test --set agentSandbox.install=true | grep "agent-sandbox"
```

- [ ] **Step 5: Verify render with agentSandbox.install=false produces nothing**

```bash
helm template test charts/dg-platform-agent --set existingSecret=test --set agentSandbox.install=false | grep "agent-sandbox" | wc -l
# Expected: 0
```

- [ ] **Step 6: Commit**

```bash
git add charts/dg-platform-agent/templates/agent-sandbox-*.yaml
git commit -m "feat(dg-platform-agent): add conditional agent-sandbox controller (v0.2.1)"
```

---

## Task 7: Add SandboxTemplate, WarmPool, and NetworkPolicy

**Files:**
- Create: `charts/dg-platform-agent/templates/sandbox-template.yaml`
- Create: `charts/dg-platform-agent/templates/sandbox-warmpool.yaml`
- Create: `charts/dg-platform-agent/templates/network-policy.yaml`

- [ ] **Step 1: Create sandbox-template.yaml**

Reference: `/dg_platform/agents/k8s/base/sandbox-template.yaml` for the spec shape.

```yaml
{{- if .Values.sandboxTemplate.create -}}
apiVersion: extensions.agents.x-k8s.io/v1alpha1
kind: SandboxTemplate
metadata:
  name: {{ .Values.sandbox.templateName }}
  namespace: {{ include "dg-platform-agent.sandboxNamespace" . }}
  labels:
    {{- include "dg-platform-agent.labels" . | nindent 4 }}
spec:
  podTemplate:
    spec:
      {{- $ghcrName := include "dg-platform-agent.ghcrSecretName" . }}
      {{- if $ghcrName }}
      imagePullSecrets:
        - name: {{ $ghcrName }}
      {{- end }}
      containers:
        - name: agent
          image: {{ .Values.agentPod.image.repository }}:{{ .Values.agentPod.image.tag }}
          ports:
            - containerPort: 8080
          resources:
            {{- toYaml .Values.sandboxTemplate.resources | nindent 12 }}
          volumeMounts:
            - name: workspace
              mountPath: /work
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            readOnlyRootFilesystem: false
            capabilities:
              drop:
                - ALL
      volumes:
        - name: workspace
          emptyDir:
            sizeLimit: {{ .Values.sandboxTemplate.workspaceSize }}
  {{- if .Values.sandboxTemplate.networkPolicy.managed }}
  networkPolicyManagement: Managed
  networkPolicy:
    egress:
      - to:
          - namespaceSelector: {}
        ports:
          - protocol: UDP
            port: 53
          - protocol: TCP
            port: 53
      - to:
          - ipBlock:
              cidr: 0.0.0.0/0
              except:
                - 10.0.0.0/8
                - 172.16.0.0/12
                - 192.168.0.0/16
        ports:
          - protocol: TCP
            port: 443
      - to:
          - ipBlock:
              cidr: 0.0.0.0/0
              except:
                - 10.0.0.0/8
                - 172.16.0.0/12
                - 192.168.0.0/16
        ports:
          - protocol: TCP
            port: 22
      - to:
          - ipBlock:
              cidr: 10.0.0.0/8
        ports:
          - protocol: TCP
            port: 443
          - protocol: TCP
            port: 6443
  {{- else }}
  networkPolicyManagement: Unmanaged
  {{- end }}
{{- end }}
```

- [ ] **Step 2: Create sandbox-warmpool.yaml**

```yaml
{{- if .Values.sandboxWarmPool.enabled -}}
apiVersion: extensions.agents.x-k8s.io/v1alpha1
kind: SandboxWarmPool
metadata:
  name: {{ .Values.sandbox.templateName }}-warmpool
  namespace: {{ include "dg-platform-agent.sandboxNamespace" . }}
  labels:
    {{- include "dg-platform-agent.labels" . | nindent 4 }}
spec:
  templateRef:
    name: {{ .Values.sandbox.templateName }}
  replicas: {{ .Values.sandboxWarmPool.replicas }}
{{- end }}
```

- [ ] **Step 3: Create network-policy.yaml**

Reference: `/dg_platform/agents/k8s/base/network-policy.yaml`.

```yaml
{{- if .Values.networkPolicy.enabled -}}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "dg-platform-agent.fullname" . }}-agent-pods
  namespace: {{ include "dg-platform-agent.sandboxNamespace" . }}
  labels:
    {{- include "dg-platform-agent.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      agents.x-k8s.io/sandbox-template: {{ .Values.sandbox.templateName }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              dg-role: controller
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8
              - 172.16.0.0/12
              - 192.168.0.0/16
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 22
    - to:
        - ipBlock:
            cidr: 10.0.0.0/8
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 6443
{{- end }}
```

- [ ] **Step 4: Verify render**

```bash
helm template test charts/dg-platform-agent --set existingSecret=test | grep "kind: SandboxTemplate" -A 5
helm template test charts/dg-platform-agent --set existingSecret=test --set sandboxWarmPool.enabled=true | grep "kind: SandboxWarmPool" -A 5
helm template test charts/dg-platform-agent --set existingSecret=test | grep "kind: NetworkPolicy" -A 5
```

- [ ] **Step 5: Commit**

```bash
git add charts/dg-platform-agent/templates/sandbox-template.yaml \
        charts/dg-platform-agent/templates/sandbox-warmpool.yaml \
        charts/dg-platform-agent/templates/network-policy.yaml
git commit -m "feat(dg-platform-agent): add SandboxTemplate, WarmPool, NetworkPolicy"
```

---

## Task 8: Add ExternalSecret templates

**Files:**
- Rewrite: `charts/dg-platform-agent/templates/externalsecret.yaml`
- Create: `charts/dg-platform-agent/templates/externalsecret-ghcr.yaml`

- [ ] **Step 1: Rewrite externalsecret.yaml for credentials**

```yaml
{{- if .Values.externalSecret.enabled -}}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ include "dg-platform-agent.fullname" . }}
  labels:
    {{- include "dg-platform-agent.labels" . | nindent 4 }}
spec:
  refreshInterval: {{ .Values.externalSecret.refreshInterval }}
  secretStoreRef:
    name: {{ .Values.externalSecret.secretStoreRef.name }}
    kind: {{ .Values.externalSecret.secretStoreRef.kind }}
  target:
    name: {{ include "dg-platform-agent.fullname" . }}
    creationPolicy: Owner
  {{- with .Values.externalSecret.data }}
  data:
    {{- range . }}
    - secretKey: {{ .secretKey }}
      remoteRef:
        key: {{ .remoteRef.key | quote }}
        {{- if .remoteRef.property }}
        property: {{ .remoteRef.property | quote }}
        {{- end }}
    {{- end }}
  {{- end }}
  {{- with .Values.externalSecret.dataFrom }}
  dataFrom:
    {{- range . }}
    - extract:
        key: {{ .key | quote }}
    {{- end }}
  {{- end }}
{{- end }}
```

- [ ] **Step 2: Create externalsecret-ghcr.yaml**

```yaml
{{- if .Values.ghcr.externalSecret.enabled -}}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ include "dg-platform-agent.fullname" . }}-ghcr
  labels:
    {{- include "dg-platform-agent.labels" . | nindent 4 }}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: {{ .Values.ghcr.externalSecret.secretStoreRef.name }}
    kind: {{ .Values.ghcr.externalSecret.secretStoreRef.kind }}
  target:
    name: {{ include "dg-platform-agent.fullname" . }}-ghcr
    creationPolicy: Owner
    template:
      type: kubernetes.io/dockerconfigjson
  data:
    - secretKey: .dockerconfigjson
      remoteRef:
        key: {{ .Values.ghcr.externalSecret.remoteRef.key | quote }}
{{- end }}
```

- [ ] **Step 3: Verify render with ESO enabled**

```bash
helm template test charts/dg-platform-agent \
  --set externalSecret.enabled=true \
  --set externalSecret.secretStoreRef.name=aws-sm \
  --set externalSecret.data[0].secretKey=DG_API_KEY \
  --set externalSecret.data[0].remoteRef.key=dev/agent \
  --set externalSecret.data[0].remoteRef.property=api_key \
  | grep "kind: ExternalSecret" -A 20
```

- [ ] **Step 4: Commit**

```bash
git add charts/dg-platform-agent/templates/externalsecret.yaml \
        charts/dg-platform-agent/templates/externalsecret-ghcr.yaml
git commit -m "feat(dg-platform-agent): rewrite ExternalSecret templates for credentials + GHCR"
```

---

## Task 9: Write NOTES.txt and README.md

**Files:**
- Rewrite: `charts/dg-platform-agent/templates/NOTES.txt`
- Create: `charts/dg-platform-agent/README.md`

- [ ] **Step 1: Rewrite NOTES.txt**

```
DevOps Genie Agent installed successfully!

Controller: {{ include "dg-platform-agent.fullname" . }}-controller
Namespace:  {{ .Release.Namespace }}

The controller will authenticate with:
  Auth URL: {{ .Values.server.authUrl }}
  WS URL:   {{ .Values.server.wsUrl }}

Check connection status:
  kubectl get pods -n {{ .Release.Namespace }} -l app.kubernetes.io/component=controller,app.kubernetes.io/instance={{ .Release.Name }}
  kubectl logs -n {{ .Release.Namespace }} -l app.kubernetes.io/component=controller,app.kubernetes.io/instance={{ .Release.Name }} -f

{{- if .Values.agentSandbox.install }}

Agent Sandbox controller installed in namespace: agent-sandbox-system
  kubectl get pods -n agent-sandbox-system
{{- end }}

{{- $secretName := include "dg-platform-agent.secretName" . }}
{{- if not $secretName }}

⚠️  WARNING: No agent credentials configured!
Create a secret with DG_AGENT_ID and DG_API_KEY:

  kubectl create secret generic {{ include "dg-platform-agent.fullname" . }} \
    --from-literal=DG_AGENT_ID=<your-agent-id> \
    --from-literal=DG_API_KEY=<your-api-key> \
    -n {{ .Release.Namespace }}

Then set existingSecret={{ include "dg-platform-agent.fullname" . }} in your values.
{{- end }}
```

- [ ] **Step 2: Write README.md**

Cover: overview, prerequisites, quickstart install, values table, GHCR setup, ExternalSecret examples, RBAC explanation, agent-sandbox toggle. Reference the `devops-genie` chart README for style.

- [ ] **Step 3: Commit**

```bash
git add charts/dg-platform-agent/templates/NOTES.txt \
        charts/dg-platform-agent/README.md
git commit -m "docs(dg-platform-agent): add README and rewrite NOTES.txt"
```

---

## Task 10: Full chart validation

- [ ] **Step 1: Run helm lint**

```bash
cd /devopsgenie-charts
helm lint charts/dg-platform-agent
```

- [ ] **Step 2: Run helm template with defaults**

```bash
helm template test charts/dg-platform-agent --set existingSecret=test
```

- [ ] **Step 3: Run helm template with agentSandbox disabled**

```bash
helm template test charts/dg-platform-agent --set existingSecret=test --set agentSandbox.install=false | grep "agent-sandbox" | wc -l
# Expected: 0 (only CRDs, which are in crds/ not templates)
```

- [ ] **Step 4: Run helm template with ESO enabled**

```bash
helm template test charts/dg-platform-agent \
  --set externalSecret.enabled=true \
  --set externalSecret.secretStoreRef.name=aws-sm \
  --set ghcr.externalSecret.enabled=true \
  --set ghcr.externalSecret.secretStoreRef.name=aws-sm \
  --set ghcr.externalSecret.remoteRef.key=ghcr-token
```

- [ ] **Step 5: Run helm template with warm pool**

```bash
helm template test charts/dg-platform-agent --set existingSecret=test --set sandboxWarmPool.enabled=true | grep "SandboxWarmPool"
```

- [ ] **Step 6: Fix any issues and commit**

```bash
git add -A charts/dg-platform-agent/
git commit -m "fix(dg-platform-agent): fix lint/template issues from validation"
```

---

## Task 11: Update kube-addon (dg-k8s-deployment)

**Files:**
- Rewrite: `/dg-k8s-deployment/kube-addons/dg-platform-agent/helm-values/dev-us-east-1.yaml`
- Modify: `/dg-k8s-deployment/kube-addons/dg-platform-agent/base/application.yaml`
- Modify: `/dg-k8s-deployment/kube-addons/dg-platform-agent/dev/dev-us-east-1/kustomization.yaml`
- Create: `/dg-k8s-deployment/kube-addons/dg-platform-agent/additional-manifests/base/kustomization.yaml`
- Create: `/dg-k8s-deployment/kube-addons/dg-platform-agent/additional-manifests/base/ghcr-external-secret.yaml`
- Create: `/dg-k8s-deployment/kube-addons/dg-platform-agent/additional-manifests/overlays/dev-us-east-1/kustomization.yaml`

- [ ] **Step 1: Rewrite helm-values/dev-us-east-1.yaml**

Remove all ws-gateway values. Add new schema values:

```yaml
fullnameOverride: "dg-platform-agent"

controller:
  image:
    repository: ghcr.io/devopsgenie-ai/dg-controller
    tag: "0.1.0"
    pullPolicy: IfNotPresent
  replicaCount: 1

server:
  wsUrl: "wss://dev.devopsgenie.com/ws/agent"
  authUrl: "https://dev.devopsgenie.com/api/v1/agents/auth"

agentPod:
  image:
    repository: ghcr.io/devopsgenie-ai/dg-agent-pod
    tag: "0.1.0"

sandbox:
  templateName: "dg-agent-pod"
  maxConcurrentPods: 10

sandboxTemplate:
  create: true
  resources:
    requests:
      memory: "2Gi"
      cpu: "1"
    limits:
      memory: "4Gi"
      cpu: "2"

agentSandbox:
  install: false

ghcr:
  existingSecret: "ghcr"

rbac:
  create: true

serviceAccount:
  create: true

externalSecret:
  enabled: true
  secretStoreRef:
    name: aws-secretsmanager-secrets-store
    kind: ClusterSecretStore
  data:
    - secretKey: DG_AGENT_ID
      remoteRef:
        key: dev/dg-platform-agent
        property: agent_id
    - secretKey: DG_API_KEY
      remoteRef:
        key: dev/dg-platform-agent
        property: api_key

networkPolicy:
  enabled: true
```

- [ ] **Step 2: Add third source to base/application.yaml**

Add the `additional-manifests` kustomize source (third Argo source):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dg-platform-agent
  namespace: argocd
spec:
  project: devops
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    automated:
      enabled: true
      prune: true
      selfHeal: false
  destination:
    namespace: devopsgenie
    server: https://kubernetes.default.svc
  sources:
    - repoURL: https://github.com/devopsgenie-ai/devopsgenie-charts.git
      targetRevision: main
      path: charts/dg-platform-agent
      helm:
        releaseName: dg-platform-agent
        valueFiles:
          - $values/kube-addons/dg-platform-agent/helm-values/{{cluster}}.yaml
    - repoURL: https://github.com/devopsgenie-ai/dg-k8s-deployment.git
      targetRevision: main
      ref: values
    - repoURL: https://github.com/devopsgenie-ai/dg-k8s-deployment.git
      path: kube-addons/dg-platform-agent/additional-manifests/overlays/{{cluster}}
      targetRevision: main
```

- [ ] **Step 3: Update dev/dev-us-east-1/kustomization.yaml**

Add patch for the third source:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namePrefix: dev-us-east-1-

resources:
  - ../../base

patches:
  - patch: |-
      - op: add
        path: /spec/destination
        value: {"namespace": "devopsgenie", "name": "dev-us-east-1"}
      - op: replace
        path: /spec/sources/0/targetRevision
        value: main
      - op: replace
        path: /spec/sources/0/helm/valueFiles/0
        value: "$values/kube-addons/dg-platform-agent/helm-values/dev-us-east-1.yaml"
      - op: replace
        path: /spec/sources/1/targetRevision
        value: main
      - op: replace
        path: /spec/sources/2/path
        value: kube-addons/dg-platform-agent/additional-manifests/overlays/dev-us-east-1
      - op: replace
        path: /spec/sources/2/targetRevision
        value: main
    target:
      group: argoproj.io
      kind: Application
      name: dg-platform-agent
      version: v1alpha1
```

- [ ] **Step 4: Create additional-manifests/base/ghcr-external-secret.yaml**

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: dg-platform-agent-ghcr
  labels:
    app.kubernetes.io/name: dg-platform-agent-ghcr
    app.kubernetes.io/part-of: dg-platform-agent
  namespace: devopsgenie
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager-secrets-store
    kind: ClusterSecretStore
  target:
    name: ghcr
    creationPolicy: Owner
    template:
      type: kubernetes.io/dockerconfigjson
  data:
    - secretKey: .dockerconfigjson
      remoteRef:
        key: dev/ghcr-pull-secret
```

- [ ] **Step 5: Create additional-manifests/base/kustomization.yaml**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ghcr-external-secret.yaml
```

- [ ] **Step 6: Create additional-manifests/overlays/dev-us-east-1/kustomization.yaml**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base
```

- [ ] **Step 7: Validate kustomize build**

```bash
cd /dg-k8s-deployment
kustomize build kube-addons/dev
```

- [ ] **Step 8: Commit (in dg-k8s-deployment repo)**

```bash
cd /dg-k8s-deployment
git add kube-addons/dg-platform-agent/
git commit -m "feat(dg-platform-agent): update addon for redesigned chart + GHCR ExternalSecret"
```

---

## Task 12: Update CI lint-test workflow

**Files:**
- Modify: `/devopsgenie-charts/.github/workflows/lint-test.yml`

- [ ] **Step 1: Update helm template command for dg-platform-agent**

Find the existing `helm template` line for `dg-platform-agent` and update to pass required values:

```bash
helm template dg-platform-agent charts/dg-platform-agent \
  --set existingSecret=test-secret \
  --set ghcr.existingSecret=ghcr
```

- [ ] **Step 2: Add additional template test variants**

```bash
helm template dg-platform-agent-no-sandbox charts/dg-platform-agent \
  --set existingSecret=test-secret \
  --set ghcr.existingSecret=ghcr \
  --set agentSandbox.install=false

helm template dg-platform-agent-eso charts/dg-platform-agent \
  --set externalSecret.enabled=true \
  --set externalSecret.secretStoreRef.name=aws-sm \
  --set ghcr.externalSecret.enabled=true \
  --set ghcr.externalSecret.secretStoreRef.name=aws-sm \
  --set ghcr.externalSecret.remoteRef.key=ghcr-token
```

- [ ] **Step 3: Commit**

```bash
cd /devopsgenie-charts
git add .github/workflows/lint-test.yml
git commit -m "ci(dg-platform-agent): update lint-test for new chart values schema"
```
