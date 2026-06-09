# traffic-gateway

Helm chart for the local APISIX entrypoint layer.

Contents:

- APISIX gateway
- APISIX Ingress Controller
- IngressClass `apisix`
- frontend route `/` -> `ruoyi-frontend`
- backend route `/prod-api` -> `ruoyi-backend-gateway`
- APISIX plugin config for backend rate limiting

Default local access target after install:

- `http://localhost:30080/`
- `http://localhost:30080/prod-api/...`
