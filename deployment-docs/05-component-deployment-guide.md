# 组件部署说明

> 目标：说明当前这套本机 K8s 环境里，各组件的部署前置条件、与其他服务的集成关系、部署时要盯的关键点，以及高频关注的问题和指标。  
> 适用范围：`RuoYi-Cloud-Plus + ruoyi-plus-soybean + Docker Desktop Kubernetes + Helm`

## 1. Kubernetes

### 作用

- 承载所有中间件、业务服务和可观测组件。
- 提供 Service、Deployment、PVC、Namespace、ConfigMap、Secret 等基础能力。

### 前置条件

- Docker Desktop 已开启 Kubernetes。
- 本机资源建议：
  - CPU：6 到 8 核
  - 内存：18GB 到 22GB
  - 磁盘：80GB 以上
- 本机工具可用：
  - `kubectl`
  - `helm`

### 与其他组件的集成

- 所有服务都通过 K8s Service DNS 通信。
- Helm chart 最终都渲染为 K8s 原生对象。
- Prometheus 通过 `ServiceMonitor` 抓取指标。
- APISIX 通过 Service 访问后端服务。

### 高频关注

- `kubectl get pods -A`
- `kubectl get svc -A`
- `kubectl get pvc -A`
- `kubectl describe pod`
- Pod 重启次数、探针状态、PVC 绑定状态

### 常见问题

- Docker Desktop 资源太小，导致 Java 服务 OOM 或探针超时。
- 单节点环境下探针配置过紧，服务还没完成启动就被杀掉。
- 本机网络抖动导致 `kubectl` API 超时。

## 2. Helm

### 作用

- 统一管理整个环境的安装、升级、回滚。

### 前置条件

- Helm CLI 可用。
- Chart 结构清晰，按层拆分：
  - `platform-infra`
  - `traffic-gateway`
  - `ruoyi-backend`
  - `ruoyi-frontend`
  - `observability`
  - `observability-addons`
  - `observability-tracing`

### 与其他组件的集成

- Helm 是所有组件的部署入口。
- values 决定镜像、资源、端口、探针、外部暴露方式。

### 高频关注

- `helm list -A`
- `helm status <release> -n <namespace>`
- release 状态是否是 `deployed`
- 是否存在遗留资源与 Helm 所有权冲突

### 常见问题

- 手工创建过的 Secret/Service 与 Helm 资源同名，导致 upgrade 失败。
- 第三方 chart 下载慢，导致本地实验环境不稳定。
- values 修改后忘记 `helm upgrade`，集群状态与文件状态不一致。

## 3. MySQL

### 作用

- 存储业务数据、Nacos 配置中心数据、任务数据、工作流数据。

### 前置条件

- `platform-infra` 中 MySQL Pod 正常。
- 初始化数据库存在：
  - `ry-cloud`
  - `ry-config`
  - `ry-job`
  - `ry-workflow`
- 已导入：
  - `ry-cloud.sql`
  - `ry-config.sql`
  - `ry-job.sql`
  - `ry-workflow.sql`

### 与其他组件的集成

- `Nacos` 使用 `ry-config`
- `system/resource` 等业务服务使用 `ry-cloud`
- `job` 使用 `ry-job`
- `workflow` 使用 `ry-workflow`

### 关键配置

- 用户必须允许从集群内地址连接：
  - `ruoyi@'%'`
- 字符集建议 `utf8mb4`
- `platform-infra` 的初始化脚本需要包含授权语句

### 高频关注

- 连接数、慢查询、初始化耗时
- Pod 首次启动是否因为初始化时间过长被探针误杀
- 表结构是否真的导入成功

### 常见问题

- `Host 'x.x.x.x' is not allowed to connect to this MySQL server`
- `ry-config` 未导入，导致 Nacos 报 `No DataSource set`
- 首次初始化时，liveness probe 太早触发

## 4. Redis

### 作用

- 登录状态、缓存、分布式锁、验证码、会话类数据。

### 前置条件

- Redis Pod 正常。
- 密码与 Nacos 配置中的 `spring.data.redis.password` 一致。

### 与其他组件的集成

- 后端服务通过 Redisson / RedisTemplate 访问 Redis。
- `gateway/auth/system/resource` 都可能依赖 Redis。

### 高频关注

- 连接是否正常建立
- Redisson 初始化日志
- key 前缀是否合理

### 常见问题

- Redis 密码不一致，服务启动时会卡在连接阶段。
- 地址未替换成 K8s Service DNS，仍指向 `localhost`。

## 5. Kafka

### 作用

- 为消息流、事件流、后续日志/异步场景提供基础设施。

### 前置条件

- KRaft 单节点 Kafka Pod 正常。
- 集群内 Service 暴露 `9092` 和 `9093`。

### 与其他组件的集成

- 当前业务链路不是强依赖 Kafka。
- 更偏向后续扩展的消息基础设施。

### 高频关注

- broker 是否真正进入 `READY`
- KRaft metadata 是否初始化成功
- liveness/readiness 是否过早

### 常见问题

- 启动慢被探针杀掉。
- KRaft metadata 已格式化但容器反复重启。

## 6. Nacos

### 作用

- 配置中心 + 注册中心。

### 前置条件

- `ry-config` 表结构已导入。
- MySQL 中存在 `ruoyi@'%'` 授权。
- `application.properties` 中数据库配置正确。

### 与其他组件的集成

- `gateway/auth/system/resource/monitor` 启动时从 Nacos 拉配置。
- 这些服务也会注册到 Nacos。
- Prometheus 通过 `/nacos/actuator/prometheus` 抓 Nacos 指标。

### 关键配置

- `db.url.0`
- `db.user.0`
- `db.password.0`
- `nacos.core.auth.*`
- `spring.boot.admin.client.*`

### 高频关注

- `/nacos/v1/console/health/liveness`
- `/nacos/v1/console/health/readiness`
- 是否能看到服务注册
- 配置发布是否成功

### 常见问题

- `No DataSource set`
- `Host ... is not allowed to connect`
- 配置虽然发布了，但服务仍拉不到，通常是 `tenant/group/dataId` 不匹配
- 启动窗口长，探针需要放宽

## 7. APISIX

### 作用

- 统一对外 HTTP 入口。
- 承接路由、转发、限流、重写、指标暴露。

### 前置条件

- `traffic-gateway` 已安装。
- APISIX 自身 Pod 正常。
- APISIX 依赖的 etcd 正常。
- backend / frontend 服务已存在。

### 与其他组件的集成

- `/` -> 前端
- `/prod-api/**` -> `gateway`
- metrics -> Prometheus

### 关键配置

- `proxy-rewrite`
- `limit-count`
- `NodePort 30080`
- `ApisixRoute`
- `ApisixPluginConfig`

### 高频关注

- APISIX admin 初始化是否成功
- `traffic-gateway-external-etcd` 是否可连
- `/prod-api` 是否正确重写到 `/`
- APISIX metrics 是否被 Prometheus 抓到

### 常见问题

- APISIX 首次启动时 etcd 尚未就绪，导致初始化失败退出。
- 路由通了但路径没改写，后端返回 401/404。
- 入口多套并存会让排障变复杂，当前环境统一只保留 APISIX 为业务入口。

## 8. Ingress / 外部访问

### 作用

- 在本机环境里，HTTP 主入口用 APISIX NodePort。
- 管理页面采用额外 NodePort Service 暴露，避免子路径代理兼容问题。

### 当前外部入口

- 前端/APISIX：`30080`
- Nacos：`30848`
- Grafana：`30300`
- Prometheus：`30900`
- SkyWalking UI：`30081`

### 高频关注

- NodePort 是否冲突
- Service targetPort 是否正确
- 宿主机直接访问是否返回 200/302

### 常见问题

- Service `targetPort` 配错，表现为能连上端口但返回空响应。
- 使用子路径暴露 Grafana/Prometheus 时，静态资源或重定向处理复杂。

## 9. RuoYi 后端服务

### 作用

- `gateway`：统一转发与鉴权入口
- `auth`：登录鉴权
- `system`：核心业务
- `resource`：文件资源服务
- `monitor`：Spring Boot Admin 监控

### 前置条件

- 本地镜像已构建：
  - `local/ruoyi-gateway`
  - `local/ruoyi-auth`
  - `local/ruoyi-system`
  - `local/ruoyi-resource`
  - `local/ruoyi-monitor`
- Nacos、Redis、MySQL 已就绪
- SQL 已导入
- Nacos 配置已发布

### 与其他组件的集成

- 从 Nacos 拉配置
- 注册到 Nacos
- 通过 Redis 建立缓存/会话能力
- 通过 MySQL 读写业务数据
- 通过 SkyWalking agent 上报 trace
- 通过 `/actuator/prometheus` 暴露指标

### 高频关注

- Java 服务首次启动时间
- health probe 是否合理
- `/actuator/health`
- `/actuator/prometheus`
- Nacos 注册日志

### 常见问题

- JVM 太大导致单机 OOM
- Basic Auth 保护 actuator，Prometheus 抓取失败
- `localhost` 未替换成集群 Service DNS

## 10. 前端 ruoyi-plus-soybean

### 作用

- 提供业务 UI 页面。

### 前置条件

- `local/ruoyi-plus-soybean:latest` 已构建
- Nginx 容器镜像可运行
- 前端 API 基础路径已指向 `/prod-api`

### 与其他组件的集成

- 通过 APISIX 访问后端
- 与后端的 `clientId`、接口加密配置要一致

### 高频关注

- 根路径是否返回 HTML
- 登录页能否正常拉验证码
- 静态资源路径是否正确

### 常见问题

- Node 版本不匹配导致构建失败
- `pnpm-workspace.yaml` 中构建放行配置不正确
- `VITE_APP_BASE_API` 没改，前端请求打错地址

## 11. Prometheus

### 作用

- 指标采集与查询。

### 前置条件

- `kube-prometheus-stack` 已安装。
- `ServiceMonitor` 已存在。
- 后端 actuator prometheus 已可访问。

### 与其他组件的集成

- 抓取：
  - `gateway/auth/system/resource/monitor`
  - `APISIX`
  - `Nacos`
  - `Alloy`

### 高频关注

- targets 是否 `up`
- 抓取失败的 `lastError`
- Prometheus 自身内存占用

### 常见问题

- 后端指标端点有 Basic Auth，没带认证就会抓取失败。
- ServiceMonitor 有了，但 selector 不匹配，Prometheus 看不到 target。

## 12. Grafana

### 作用

- 查看 Prometheus 指标和 Loki 日志。

### 前置条件

- Grafana Pod 正常
- Prometheus datasource 已可用
- Loki datasource 已可用

### 与其他组件的集成

- 指标来自 Prometheus
- 日志来自 Loki
- 后续可导入项目自带 dashboard

### 高频关注

- `/api/health`
- datasource 状态
- dashboard 是否成功导入

### 常见问题

- 对外 Service targetPort 配错会导致空响应。
- 密码来自 Secret，重装后可能变化。

## 13. Loki + Alloy

### 作用

- Loki：日志存储与查询
- Alloy：K8s Pod 日志采集

### 前置条件

- Loki Pod 正常
- Alloy DaemonSet 正常

### 与其他组件的集成

- Alloy 抓取各 namespace 下的 Pod stdout
- Grafana 通过 Loki datasource 查询日志

### 高频关注

- Alloy 是否正常发现 Pod
- Loki 是否能按 `namespace/pod/container/app` 查询

### 常见问题

- 标签不完整导致日志难查
- 采集器运行正常，但 Grafana datasource 未配置

## 14. SkyWalking

### 作用

- 链路追踪和拓扑分析。

### 前置条件

- `skywalking-oap` 正常
- `skywalking-ui` 正常
- 后端服务已注入 agent

### 与其他组件的集成

- Java 服务通过 `-javaagent` 上报到 OAP
- UI 从 OAP 读取 trace 和拓扑数据

### 高频关注

- `oap` 的 gRPC 端口 `11800`
- UI 是否能连到 OAP `12800`
- `gateway -> auth -> system` 是否能串成 trace

### 常见问题

- OAP 启动慢，startup probe 过早失败
- UI 起得快但 OAP 还没就绪，会短时间报连接拒绝

## 15. 你应该优先盯什么

如果你是为了“快速掌握这套架构怎么运转”，优先看这几层：

1. `Nacos`
   - 配置是否能拉取
   - 服务是否能注册
2. `APISIX`
   - `/prod-api` 是否正确转发
   - 路由和限流怎么做
3. `gateway/auth/system`
   - 登录链路是否通
   - actuator/metrics 是否暴露
4. `Prometheus + Grafana`
   - target 是否全 `up`
   - 关键 JVM / HTTP / Redis / APISIX 指标是否能看到
5. `SkyWalking`
   - 业务 trace 是否连起来

## 16. 最常用排障命令

```bash
kubectl get pods -A
kubectl get svc -A
kubectl describe pod -n <namespace> <pod>
kubectl logs -n <namespace> <pod> --tail=200
helm list -A
helm status <release> -n <namespace>
```

## 17. 当前这套环境的判断标准

只要满足下面这些，就说明这套环境已经进入“可学习、可排障、可扩展”的状态：

- Helm release 全部 `deployed`
- `infra / apisix / observability / ruoyi` 关键 Pod 全部 `Running`
- `http://127.0.0.1:30080/` 可访问
- `http://127.0.0.1:30080/prod-api/auth/code` 返回 `200`
- Prometheus targets 中核心业务服务为 `up`
- Grafana 可打开
- SkyWalking UI 可打开
