{{- define "blog-api.name" -}}
blog-api
{{- end -}}

{{- define "blog-api.fullname" -}}
{{ .Release.Name }}-blog-api
{{- end -}}
