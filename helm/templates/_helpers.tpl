{{/*
Expand the name of the chart.
*/}}
{{- define "juiceshop-chatbot.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "juiceshop-chatbot.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "juiceshop-chatbot.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "juiceshop-chatbot.labels" -}}
helm.sh/chart: {{ include "juiceshop-chatbot.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ include "juiceshop-chatbot.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- with .Values.globalLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "juiceshop-chatbot.selectorLabels" -}}
app.kubernetes.io/name: {{ printf "%s-%s" (include "juiceshop-chatbot.name" .root) .component }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "juiceshop-chatbot.frontend.fullname" -}}
{{- printf "%s-frontend" (include "juiceshop-chatbot.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "juiceshop-chatbot.backend.fullname" -}}
{{- printf "%s-backend" (include "juiceshop-chatbot.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "juiceshop-chatbot.chromadb.fullname" -}}
{{- printf "%s-chromadb" (include "juiceshop-chatbot.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "juiceshop-chatbot.configmapName" -}}
{{- printf "%s-config" (include "juiceshop-chatbot.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "juiceshop-chatbot.secretName" -}}
{{- if .Values.backend.openai.existingSecret -}}
{{- .Values.backend.openai.existingSecret -}}
{{- else -}}
{{- printf "%s-secrets" (include "juiceshop-chatbot.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "juiceshop-chatbot.image" -}}
{{- printf "%s:%s" .repository (.tag | toString) -}}
{{- end -}}
