# 访问入口总览表

> 当前环境：Docker Desktop Kubernetes + Helm  
> 宿主机访问地址统一使用 `127.0.0.1`

## 宿主机访问入口

| 模块 | 用途 | 地址 | 验证结果 | 备注 |
|---|---|---|---|---|
| RuoYi 前端 | 业务主入口 | `http://127.0.0.1:30080/` | `200` | 通过 APISIX 暴露 |
| RuoYi API | 后端统一入口 | `http://127.0.0.1:30080/prod-api` | 可达 | 通过 APISIX 转发到 `gateway` |
| 验证码接口 | 登录链路验证 | `http://127.0.0.1:30080/prod-api/auth/code` | `200` | 用于快速确认 `gateway -> auth` |
| Nacos | 配置中心 | `http://127.0.0.1:30848/nacos/` | `200` | 通过 `NodePort` 暴露 |
| Grafana | 指标/日志可视化 | `http://127.0.0.1:30300/` | `api/health=200` | 根路径可访问，健康接口已验证 |
| Prometheus | 指标查询 | `http://127.0.0.1:30900/` | `302` | 根路径跳转到 `/query` |
| SkyWalking UI | 链路追踪界面 | `http://127.0.0.1:30081/` | `200` | 通过 `NodePort` 暴露 |

## 登录信息

| 模块 | 用户名 | 密码 | 备注 |
|---|---|---|---|
| Grafana | `admin` | `pMQnm3qBa0UzAMKhntfDnTlZHkRekSKnJeeOaRik` | 从当前 K8s Secret 读取 |
| Nacos | `nacos` | `nacos` | 当前环境默认账号 |

## 集群内服务地址

| 模块 | 集群内地址 | 说明 |
|---|---|---|
| Nacos | `http://release-platform-infra-nacos.infra.svc.cluster.local:8848/nacos` | 服务发现与配置中心 |
| Grafana | `http://kube-prometheus-stack-grafana.observability.svc.cluster.local:80` | 可视化面板 |
| Prometheus | `http://kube-prometheus-stack-prometheus.observability.svc.cluster.local:9090` | 指标查询 |
| Loki | `http://loki.observability.svc.cluster.local:3100` | 日志存储与查询 |
| SkyWalking OAP | `skywalking-oap.observability.svc.cluster.local:11800` | agent 上报 gRPC 入口 |
| SkyWalking UI | `http://skywalking-ui.observability.svc.cluster.local:18080` | 链路追踪界面 |

## NodePort 对照

| Service | Namespace | 端口映射 |
|---|---|---|
| `apisix` | `apisix` | `30080 -> 80` |
| `release-platform-infra-nacos-external` | `infra` | `30848 -> 8848` |
| `grafana-external` | `observability` | `30300 -> 3000` |
| `prometheus-external` | `observability` | `30900 -> 9090` |
| `skywalking-ui-external` | `observability` | `30081 -> 18080` |

## 说明

- `30080` 是统一业务入口，优先用于前后端联调。
- `30300 / 30900 / 30081 / 30848` 是学习和排障用的直接入口，避免走子路径代理时的兼容问题。
- Grafana 密码来自当前集群 Secret，后续如果 Helm 重装或 Secret 轮换，密码可能变化。
