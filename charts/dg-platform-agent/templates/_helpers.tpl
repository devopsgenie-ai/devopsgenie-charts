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
Sandbox template name — constant, not user-configurable
*/}}
{{- define "dg-platform-agent.sandboxTemplateName" -}}
dg-agent-pod
{{- end }}

{{/*
Sandbox namespace — always the release namespace
*/}}
{{- define "dg-platform-agent.sandboxNamespace" -}}
{{- .Release.Namespace }}
{{- end }}

{{/*
Credentials secret name.
Priority: credentials.existingSecret > credentials.externalSecret (auto-named) > chart-created secret
*/}}
{{- define "dg-platform-agent.secretName" -}}
{{- if .Values.credentials.existingSecret -}}
{{- .Values.credentials.existingSecret }}
{{- else if .Values.credentials.externalSecret.enabled -}}
{{- printf "%s-credentials" (include "dg-platform-agent.fullname" .) }}
{{- else -}}
{{- printf "%s-credentials" (include "dg-platform-agent.fullname" .) }}
{{- end }}
{{- end }}

{{/*
GHCR pull secret name.
Priority: imageCredentials.existingSecret > chart-created secret from token > empty
*/}}
{{- define "dg-platform-agent.ghcrSecretName" -}}
{{- if .Values.imageCredentials.existingSecret -}}
{{- .Values.imageCredentials.existingSecret }}
{{- else if .Values.imageCredentials.token -}}
{{- printf "%s-ghcr" (include "dg-platform-agent.fullname" .) }}
{{- else -}}
{{- "" }}
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
Agent pod secret name.
Priority: agentPod.existingSecret > chart-created secret
*/}}
{{- define "dg-platform-agent.agentPodSecretName" -}}
{{- if .Values.agentPod.existingSecret -}}
{{- .Values.agentPod.existingSecret }}
{{- else -}}
{{- printf "%s-agent-pod" (include "dg-platform-agent.fullname" .) }}
{{- end }}
{{- end }}
