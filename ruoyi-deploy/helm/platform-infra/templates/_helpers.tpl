{{- define "platform-infra.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform-infra.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "platform-infra.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "platform-infra.nacos.fullname" -}}
{{- printf "%s-nacos" (include "platform-infra.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform-infra.mysql.fullname" -}}
{{- printf "%s-mysql" (include "platform-infra.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform-infra.redis.fullname" -}}
{{- printf "%s-redis" (include "platform-infra.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform-infra.kafka.fullname" -}}
{{- printf "%s-kafka" (include "platform-infra.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
