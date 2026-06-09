# 部署任务清单

## 阶段 0：约束与范围

- 确认 Docker Desktop Kubernetes 已启用。
- Docker Desktop 资源建议：CPU 6-8 核，内存 18-22GB，磁盘 80GB 以上。
- 后端源码目录：`RuoYi-Cloud-Plus`
- 前端源码目录：`ruoyi-plus-soybean`
- 所有部署都通过 Helm 管理。
- APISIX 作为唯一外部入口，不再额外部署 Nginx Ingress Controller。
- 日志方案采用 Loki + Promtail，不采用 ELK 作为第一阶段目标。
  - 实际执行中日志采集器改为 `Grafana Alloy`，原因是 Grafana 官方 chart 路线已转向 Alloy。

## 阶段 1：本地工具与集群基线

- 安装或确认：
  - `kubectl`
  - `helm`
  - `k9s`
  - `jq`
  - `yq`
- 验证集群：
  - `kubectl get nodes`
  - `kubectl get pods -A`
- 创建命名空间：
  - `infra`
  - `apisix`
  - `observability`
  - `ruoyi`
- 建立资源命名规范：
  - infra 组件放 `infra`
  - APISIX 放 `apisix`
  - Prometheus/Grafana/Loki/SkyWalking 放 `observability`
  - RuoYi 前后端服务放 `ruoyi`
- 当前状态：
  - `docker-desktop` 集群已连通，节点状态为 `Ready`
  - `helm` 已可用
  - `infra` / `apisix` / `observability` / `ruoyi` namespace 已创建

## 阶段 2：Helm 目录规划

建议后续创建部署资产目录，但不要放在 `deployment-docs`：

```text
deploy/
  helm/
    platform-infra/
    traffic-gateway/
    observability/
    ruoyi-backend/
    ruoyi-frontend/
```

- `platform-infra`: MySQL、Redis、Kafka、Nacos。
- `traffic-gateway`: APISIX、APISIX Ingress Controller、etcd。
- `observability`: Prometheus、Grafana、Loki、Promtail、SkyWalking。
- `ruoyi-backend`: gateway、auth、system、resource、monitor、可选 job/gen/workflow。
- `ruoyi-frontend`: ruoyi-plus-soybean 静态站点。

## 阶段 3：基础设施部署

- MySQL:
  - 部署 MySQL 8。
  - 初始化 `ry-cloud` 数据库。
  - 导入 `RuoYi-Cloud-Plus/script/sql/*.sql` 中项目所需脚本。
  - 生成 K8s Secret 保存账号密码。
- Redis:
  - 部署单节点 Redis。
  - 密码与 Nacos `application-common.yml` 中配置保持一致。
- Kafka:
  - 部署 KRaft 单节点 Kafka。
  - 暴露集群内 bootstrap service。
- Nacos:
  - 当前采用官方镜像 `nacos/nacos-server:v2.5.1-slim`。
  - 导入 `RuoYi-Cloud-Plus/script/config/nacos/*.yml`。
  - 将 MySQL、Redis、Kafka 地址改为 K8s Service DNS。
  - 当前状态：
    - `platform-infra` 已通过 Helm 安装到 `infra`
    - `MySQL` / `Redis` / `Kafka` / `Nacos` 已全部 `Running`
    - `Nacos` 已切换为官方容器目录结构，并使用外部 MySQL 存储
    - `ry-config` 已导入官方 Nacos schema

## 阶段 4：APISIX 流量入口

- Helm 部署 APISIX、etcd、APISIX Ingress Controller。
- 配置 APISIX Gateway 暴露方式：
  - 本机学习环境优先使用 `NodePort` 或 `LoadBalancer`。
- 定义 APISIX 路由：
  - `/` -> 前端服务
  - `/prod-api/**` -> `ruoyi-gateway`
  - `/nacos/**` -> Nacos 控制台，可选且建议只本机访问
  - `/grafana/**` -> Grafana，可选
  - `/skywalking/**` -> SkyWalking UI，可选
- 配置 APISIX 插件：
  - prometheus
  - limit-count 或 limit-req
  - proxy-rewrite
  - cors
  - request-id
- 当前状态：
  - `traffic-gateway` 已通过 Helm 安装到 `apisix`
  - APISIX 网关对外入口已暴露为 `http://127.0.0.1:30080`
  - `/` 已正确转发到 `ruoyi-plus-soybean` 前端
  - `/prod-api/**` 已正确转发到 `ruoyi-gateway`
  - 当前已落地的 APISIX 资源：
    - `IngressClass apisix`
    - `Ingress/ruoyi-frontend`
    - `Ingress/ruoyi-backend`
    - `ApisixPluginConfig/ruoyi-backend-rate-limit`
  - APISIX 依赖的内置 etcd 镜像已改为自管单节点 external etcd，避免上游旧 tag 无法拉取

## 阶段 5：后端服务部署

- 构建后端镜像：
  - `ruoyi-gateway`
  - `ruoyi-auth`
  - `ruoyi-system`
  - `ruoyi-resource`
  - `ruoyi-monitor`
  - 可选：`ruoyi-job`、`ruoyi-gen`、`ruoyi-workflow`
- 每个服务 Deployment 必须配置：
  - image
  - env
  - resources
  - livenessProbe
  - readinessProbe
  - Service
  - Prometheus scrape 或 ServiceMonitor
  - SkyWalking agent 参数
- 验证服务注册到 Nacos。
- 验证 gateway 能路由到 auth/system/resource。
- 当前状态：
  - `ruoyi-backend` 已通过 Helm 安装到 `ruoyi`
  - `gateway / auth / system / resource / monitor` 已全部 `1/1 Running`
  - 已针对本机单节点完成探针与资源收敛：
    - 增加 `startupProbe`
    - Servlet 服务健康检查补充 Basic Auth 头
    - JVM 参数下调到 `-Xms256m -Xmx512m`
    - Deployment 策略切为 `Recreate`

## 阶段 6：前端服务部署

- 前端目录：`ruoyi-plus-soybean`
- 构建命令：`pnpm build`
- 需要补充前端 Dockerfile：
  - build stage 使用 Node + pnpm
  - runtime stage 使用 Nginx
  - 静态文件放入 Nginx html 目录
- 生产配置重点：
  - `VITE_APP_BASE_API=/prod-api`
  - `VITE_APP_CLIENT_ID`
  - `VITE_APP_ENCRYPT`
  - RSA 公私钥与后端 `api-decrypt` 配置匹配
- 通过 APISIX 暴露前端根路径 `/`。
- 当前状态：
  - `ruoyi-frontend` 已通过 Helm 安装到 `ruoyi`
  - `ruoyi-plus-soybean` 镜像已构建为 `local/ruoyi-plus-soybean:latest`
  - 前端 Pod 已 `1/1 Running`
  - 已修正前端容器化构建基线：
    - Node 版本切换到 `node:22-bookworm-slim`
    - `pnpm-workspace.yaml` 中 `allowBuilds.es5-ext` 明确设为 `true`

## 阶段 7：可观测体系

- Prometheus/Grafana:
  - 使用 `kube-prometheus-stack`。
  - 抓取 Spring Boot Actuator `/actuator/prometheus`。
  - 抓取 APISIX metrics。
  - 抓取 Nacos metrics。
  - 导入项目 Grafana dashboard。
- Loki/Promtail:
  - Alloy 采集 Pod stdout。
  - 标签至少包含 namespace、pod、container、app。
  - Grafana 配置 Loki datasource。
- SkyWalking:
  - 部署 OAP 与 UI。
  - 后端服务注入 Java agent。
  - 验证 gateway -> auth -> system 链路 trace。
- 当前状态：
  - 观测栈尚未正式安装
  - 已确认项目已有可迁移输入：
    - `script/docker/prometheus/prometheus.yml`
    - `script/config/grafana/*.json`
  - `ruoyi-backend` 已预留 `ServiceMonitor` 模板，待 Prometheus Operator 安装后启用
  - `ruoyi-backend` 的 `ServiceMonitor` 已补充 Basic Auth 配置开关，兼容当前 `/actuator/prometheus` 受保护场景
  - `kube-prometheus-stack` 已通过本地 vendored chart 安装到 `observability`
  - `Loki` 已通过本地 vendored chart 安装到 `observability`
  - `Alloy` 已通过本地 vendored chart 安装到 `observability`
  - `observability-addons` 已安装，当前提供：
    - `ServiceMonitor/observability-addons-apisix`
    - `ServiceMonitor/observability-addons-nacos`
    - Grafana Loki datasource ConfigMap
  - 当前已验证为 `up` 的关键抓取目标：
    - `Alloy`
    - `APISIX metrics`
    - `Nacos metrics`
    - `gateway/auth/system/resource/monitor`
  - Docker Desktop 单节点下已显式移除 `node-exporter`，原因是宿主根挂载不是 shared/slave，容器会持续 CrashLoop

## 阶段 8：验收清单

- `kubectl get pods -A` 无异常重启。
- Nacos 控制台可访问，并能看到服务注册。
- MySQL 数据已初始化。
- 已补充自动化脚本：
  - `deploy/scripts/import-ruoyi-sql.sh`
  - `deploy/scripts/import-nacos-configs.sh`
- Redis 可连通。
- Kafka 可创建 topic。
- 前端可访问。
- 核心后端服务与前端均已在 K8s 内运行。
- 登录接口待 APISIX/入口路由或端口转发验证。
- APISIX route 生效。
- APISIX 限流插件可触发。
- APISIX 前端入口校验：
  - `curl http://127.0.0.1:30080/` 返回前端 HTML
- APISIX 后端入口校验：
  - `curl http://127.0.0.1:30080/prod-api/auth/code` 已返回后端应用响应
- Prometheus 关键 target 已验证：
  - `ruoyi-backend-*` 全部 `up`
  - `apisix-prometheus-metrics` 为 `up`
  - `release-platform-infra-nacos` 为 `up`
  - `alloy` 为 `up`
- Grafana 有 JVM、Nacos、K8s、APISIX 面板。
- Loki 已验证可按 label 查询：
  - `namespace`
  - `pod`
  - `container`
  - `app`
- SkyWalking 能看到核心调用链。

## 阶段 9：最终交付

- Helm values 文件。
- 关键 Kubernetes manifests 渲染说明。
- Nacos 配置导入说明。
- 架构图。
- 常用运维命令。
- 故障排查清单。
