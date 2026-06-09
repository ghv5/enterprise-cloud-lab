# ruoyi-backend

This chart manages the Java service layer for local RuoYi deployment.

## Managed Services

- `gateway`
- `auth`
- `system`
- `resource`
- `monitor`
- optional `job`

## Design

- One shared deployment template renders all backend services.
- Nacos connectivity is injected with Spring environment variables instead of rebuilding config files.
- `ServiceMonitor` support is present but disabled by default until Prometheus Operator is installed.
- SkyWalking agent mount points are reserved but disabled by default.

## Intended Namespace

- `ruoyi`

## Notes

- Default images assume locally built tags such as `local/ruoyi-gateway:latest`.
- The default Nacos address points to the `platform-infra` chart release name `release`.
- If you use a different release name for infra, override `global.nacos.serverAddr`.
