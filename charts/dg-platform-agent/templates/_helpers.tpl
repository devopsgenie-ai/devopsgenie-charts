{{/*
Expand the name of the chart.
*/}}
{{- define "dg-platform-agent.name" -}}
{{- default .Chart.Name .Values.global.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "dg-platform-agent.fullname" -}}
{{- if .Values.global.fullnameOverride }}
{{- .Values.global.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.global.nameOverride }}
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
app.kubernetes.io/name: {{ include "dg-platform-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Controller labels (includes component)
*/}}
{{- define "dg-platform-agent.controller.labels" -}}
{{ include "dg-platform-agent.labels" . }}
app.kubernetes.io/component: controller
{{- end }}

{{/*
Controller selector labels
*/}}
{{- define "dg-platform-agent.controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dg-platform-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: controller
{{- end }}

{{/*
WS Gateway labels (includes component)
*/}}
{{- define "dg-platform-agent.wsGateway.labels" -}}
{{ include "dg-platform-agent.labels" . }}
app.kubernetes.io/component: ws-gateway
{{- end }}

{{/*
WS Gateway selector labels
*/}}
{{- define "dg-platform-agent.wsGateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dg-platform-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: ws-gateway
{{- end }}

{{/*
Controller image
*/}}
{{- define "dg-platform-agent.controller.image" -}}
{{- $tag := .Values.controller.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" .Values.controller.image.repository $tag }}
{{- end }}

{{/*
WS Gateway image
*/}}
{{- define "dg-platform-agent.wsGateway.image" -}}
{{- $tag := .Values.wsGateway.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" .Values.wsGateway.image.repository $tag }}
{{- end }}

{{/*
Controller imagePullSecrets
*/}}
{{- define "dg-platform-agent.controller.imagePullSecrets" -}}
{{- with .Values.controller.image.pullSecrets }}
imagePullSecrets:
  {{- range . }}
  - name: {{ if kindIs "map" . }}{{ .name }}{{ else }}{{ . }}{{ end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
WS Gateway imagePullSecrets
*/}}
{{- define "dg-platform-agent.wsGateway.imagePullSecrets" -}}
{{- with .Values.wsGateway.image.pullSecrets }}
imagePullSecrets:
  {{- range . }}
  - name: {{ if kindIs "map" . }}{{ .name }}{{ else }}{{ . }}{{ end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Secret name for envFrom: when externalSecret.enabled use the synced secret name, else existingSecret.
*/}}
{{- define "dg-platform-agent.secretName" -}}
{{- if .Values.externalSecret.enabled -}}
{{- .Values.externalSecret.target.name | default (include "dg-platform-agent.fullname" .) }}
{{- else -}}
{{- .Values.existingSecret }}
{{- end }}
{{- end }}
