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
