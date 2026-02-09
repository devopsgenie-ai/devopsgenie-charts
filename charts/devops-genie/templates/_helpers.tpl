{{/*
Expand the name of the chart.
*/}}
{{- define "devops-genie.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "devops-genie.fullname" -}}
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
{{- define "devops-genie.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "devops-genie.labels" -}}
helm.sh/chart: {{ include "devops-genie.chart" . }}
app.kubernetes.io/name: {{ include "devops-genie.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Image (with default tag from appVersion)
*/}}
{{- define "devops-genie.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}

{{/*
Normalize imagePullSecrets to Kubernetes format (list of {name: ...}).
Accepts either ["secretname"] or [{name: "secretname"}] in values.
*/}}
{{- define "devops-genie.imagePullSecrets" -}}
{{- with .Values.image.pullSecrets }}
imagePullSecrets:
  {{- range . }}
  - name: {{ if kindIs "map" . }}{{ .name }}{{ else }}{{ . }}{{ end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Secret name for envFrom: when externalSecret.enabled use the synced secret name, else existingSecret.
*/}}
{{- define "devops-genie.secretName" -}}
{{- if .Values.externalSecret.enabled -}}
{{- .Values.externalSecret.target.name | default (include "devops-genie.fullname" .) }}
{{- else -}}
{{- .Values.existingSecret }}
{{- end }}
{{- end }}
