{{- define "ruoyi-backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ruoyi-backend.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "ruoyi-backend.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "ruoyi-backend.serviceFullname" -}}
{{- printf "%s-%s" (include "ruoyi-backend.fullname" .root) .name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
