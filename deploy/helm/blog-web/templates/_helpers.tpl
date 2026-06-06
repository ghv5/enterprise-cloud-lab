{{- define "blog-web.name" -}}
blog-web
{{- end -}}

{{- define "blog-web.fullname" -}}
{{ .Release.Name }}-blog-web
{{- end -}}
