# 关键配置文件索引

## 后端项目

| 路径 | 用途 |
|---|---|
| `RuoYi-Cloud-Plus/pom.xml` | 后端版本、依赖与模块入口。 |
| `RuoYi-Cloud-Plus/script/docker/docker-compose.yml` | 现有 Docker Compose 部署参考。 |
| `RuoYi-Cloud-Plus/script/docker/database.yml` | 数据库相关 Compose 参考。 |
| `RuoYi-Cloud-Plus/script/sql/ry-cloud.sql` | 核心业务库初始化 SQL。 |
| `RuoYi-Cloud-Plus/script/sql/ry-config.sql` | Nacos 配置库初始化 SQL。 |
| `RuoYi-Cloud-Plus/script/sql/ry-job.sql` | 任务模块初始化 SQL。 |
| `RuoYi-Cloud-Plus/script/sql/ry-workflow.sql` | 工作流模块初始化 SQL。 |
| `RuoYi-Cloud-Plus/script/config/nacos/application-common.yml` | 公共 Nacos 配置。 |
| `RuoYi-Cloud-Plus/script/config/nacos/datasource.yml` | 数据源配置。 |
| `RuoYi-Cloud-Plus/script/config/nacos/ruoyi-gateway.yml` | gateway 服务配置。 |
| `RuoYi-Cloud-Plus/script/config/nacos/ruoyi-auth.yml` | auth 服务配置。 |
| `RuoYi-Cloud-Plus/script/config/nacos/ruoyi-system.yml` | system 服务配置。 |
| `RuoYi-Cloud-Plus/script/config/nacos/ruoyi-resource.yml` | resource 服务配置。 |
| `RuoYi-Cloud-Plus/script/docker/prometheus/prometheus.yml` | 现有 Prometheus 抓取配置参考。 |
| `RuoYi-Cloud-Plus/script/config/grafana/*.json` | 项目现有 Grafana 面板。 |
| `RuoYi-Cloud-Plus/script/docker/skywalking/agent/` | SkyWalking Java agent 参考。 |
| `RuoYi-Cloud-Plus/ruoyi-gateway/Dockerfile` | gateway 镜像构建参考。 |
| `RuoYi-Cloud-Plus/ruoyi-auth/Dockerfile` | auth 镜像构建参考。 |
| `RuoYi-Cloud-Plus/ruoyi-modules/ruoyi-system/Dockerfile` | system 镜像构建参考。 |
| `RuoYi-Cloud-Plus/ruoyi-modules/ruoyi-resource/Dockerfile` | resource 镜像构建参考。 |

## 前端项目

| 路径 | 用途 |
|---|---|
| `ruoyi-plus-soybean/package.json` | 前端构建脚本与 Node/pnpm 版本约束。 |
| `ruoyi-plus-soybean/pnpm-workspace.yaml` | pnpm workspace 与 build-script 放行配置。 |
| `ruoyi-plus-soybean/.env.prod` | 生产构建环境变量。 |
| `ruoyi-plus-soybean/vite.config.ts` | Vite 构建配置。 |
| `ruoyi-plus-soybean/build/config/proxy.ts` | 本地开发代理配置参考。 |
| `ruoyi-plus-soybean/Dockerfile` | 前端容器镜像构建入口。 |
| `ruoyi-plus-soybean/deploy/nginx/default.conf` | 前端静态站点 Nginx 配置。 |
| `ruoyi-plus-soybean/public/` | 静态资源。 |

## 后续需要新增但不放入本目录的大类文件

| 目标路径 | 内容 |
|---|---|
| `deploy/helm/platform-infra/` | MySQL、Redis、Kafka、Nacos chart/values。 |
| `deploy/helm/traffic-gateway/` | APISIX chart values、ApisixRoute、ApisixPluginConfig。 |
| `deploy/helm/observability/` | Prometheus、Grafana、Loki、Alloy、SkyWalking values、vendored charts 与安装说明。 |
| `deploy/helm/observability-addons/` | APISIX/Nacos ServiceMonitor 与 Grafana datasource 等补件 chart。 |
| `deploy/helm/ruoyi-backend/` | 后端服务 Helm chart。 |
| `deploy/helm/ruoyi-frontend/` | 前端服务 Helm chart。 |
| `deploy/scripts/check-local-prereqs.sh` | 本机部署前置检查脚本。 |
| `deploy/scripts/import-ruoyi-sql.sh` | MySQL 业务库初始化脚本。 |
| `deploy/scripts/import-nacos-configs.sh` | Nacos 配置渲染与导入脚本。 |

## 配置替换重点

### Nacos 配置替换

- MySQL host 改为 K8s Service DNS。
- Redis host 改为 K8s Service DNS。
- Kafka bootstrap servers 改为 K8s Service DNS。
- Nacos namespace 与 profile 对齐。
- Spring Boot Admin、Actuator、Prometheus 暴露配置确认。

### 前端配置替换

- `VITE_APP_BASE_API=/prod-api`
- APISIX 将 `/prod-api/**` 转发到 `ruoyi-gateway`。
- `VITE_APP_CLIENT_ID` 必须匹配后端客户端配置。
- `VITE_APP_ENCRYPT` 与后端 `api-decrypt.enabled` 保持一致。

### SkyWalking 配置替换

- 每个 Java 服务设置 `SW_AGENT_NAME`。
- OAP 地址使用 K8s Service DNS。
- Java 启动参数增加 `-javaagent`。

### Prometheus 配置替换

- 优先使用 `ServiceMonitor`，减少手写 scrape config。
- 保留 `script/docker/prometheus/prometheus.yml` 作为迁移参考。
- `ruoyi-backend` 的 `ServiceMonitor` 当前需要 Basic Auth Secret，默认名称为 `ruoyi-actuator-basic-auth`。
- `deploy/helm/observability-addons/` 当前承接：
  - APISIX metrics 抓取
  - Nacos metrics 抓取
  - Grafana Loki datasource

### APISIX 配置入口

- `deploy/helm/traffic-gateway/values.yaml`
- `deploy/helm/traffic-gateway/templates/frontend-ingress.yaml`
- `deploy/helm/traffic-gateway/templates/backend-ingress.yaml`
- `deploy/helm/traffic-gateway/templates/plugin-config.yaml`
- 当前本机入口：`http://127.0.0.1:30080`

### 日志接入配置替换

- `deploy/helm/observability/alloy.values.yaml`
- 当前日志采集器采用 `Grafana Alloy`，不再采用 `Promtail`
- Loki 当前接收地址：
  - `http://loki.observability.svc.cluster.local:3100/loki/api/v1/push`

## 不允许放入 `deployment-docs` 的内容

- 镜像 tar 包。
- JAR/WAR 包。
- `node_modules`。
- `dist` 构建产物。
- Helm chart 依赖压缩包。
- 数据库 dump。
- Pod 日志。
- SkyWalking agent 二进制副本。
