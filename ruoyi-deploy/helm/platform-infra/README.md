# platform-infra

This chart manages the first infrastructure layer needed by the local RuoYi deployment.

## Managed Components

- Custom MySQL deployment
- Custom Redis deployment
- Custom Kafka KRaft single-node deployment
- Custom Nacos deployment based on `local/ruoyi-nacos:2.6.1`

## Intended Namespace

- `infra`

## Notes

- The chart is self-contained and does not require remote subchart dependencies.
- Nacos stays custom because this project ships a modified Nacos image and custom `application.properties`.
- The chart assumes Docker Desktop Kubernetes and a single-node local footprint.
- Verified locally on 2026-06-04 with all four pods reaching `Running`.
