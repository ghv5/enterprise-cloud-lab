# 当前 Pod 说明文档

> 目标：说明当前这套本机 K8s 环境中，所有正在运行的 Pod 分别负责什么，以及它们所在 namespace 的职责。  
> 说明：本文基于当前集群运行状态整理，适合作为你进入集群排障时的“Pod 地图”。

## 1. namespace 总览

| Namespace | 作用 | 当前内容 |
|---|---|---|
| `kube-system` | Kubernetes 控制面与基础网络/存储 | apiserver、scheduler、controller-manager、CoreDNS、etcd、kube-proxy |
| `infra` | 基础中间件层 | MySQL、Redis、Kafka、Nacos |
| `apisix` | 统一流量入口层 | APISIX、Ingress Controller、外部 etcd |
| `ruoyi` | 业务服务层 | gateway、auth、system、resource、monitor、frontend |
| `observability` | 可观测平台层 | Prometheus、Grafana、Loki、Alloy、SkyWalking、Alertmanager |

## 2. kube-system

这一层不是你业务直接修改的对象，但它决定集群是不是活着。

### `coredns-668d6bf9bc-55fzv`
### `coredns-668d6bf9bc-fcqdg`

- 作用：集群 DNS 服务。
- 为什么重要：所有 `*.svc.cluster.local` 的服务发现都依赖它。
- 出问题的表现：
  - 应用日志里出现服务名解析失败
  - Pod 能启动，但连不到 `nacos`、`redis`、`mysql`

### `etcd-docker-desktop`

- 作用：Kubernetes 控制面元数据存储。
- 为什么重要：所有 K8s 资源对象最终都落在这里。
- 出问题的表现：
  - `kubectl` 请求异常
  - 控制面不稳定

### `kube-apiserver-docker-desktop`

- 作用：Kubernetes API 入口。
- 为什么重要：`kubectl`、controller、operator 都通过它交互。
- 出问题的表现：
  - `kubectl get pods` 直接失败
  - Helm 无法 install/upgrade

### `kube-controller-manager-docker-desktop`

- 作用：控制器调谐中心。
- 为什么重要：Deployment 拉起 Pod、副本维持、Node 状态更新都靠它。

### `kube-scheduler-docker-desktop`

- 作用：负责把 Pod 调度到节点。
- 为什么重要：如果它有问题，Pod 会一直 Pending。

### `kube-proxy-lb6sg`

- 作用：维护 Service 到 Pod 的转发规则。
- 为什么重要：Service 能不能转发，和它直接相关。

### `storage-provisioner`

- 作用：Docker Desktop 本地存储 provisioner。
- 为什么重要：PVC 能否动态绑定依赖它。

### `vpnkit-controller`

- 作用：Docker Desktop 的网络桥接组件。
- 为什么重要：NodePort、本机访问集群服务都和它有关。

## 3. infra

这一层承载业务依赖的中间件。  
业务服务大多不是直接挂，而是先因为这层不稳定而连锁失败。

### `release-platform-infra-mysql-5cb475dd56-xlj5r`

- 作用：主数据库。
- 当前承担：
  - `ry-cloud`
  - `ry-config`
  - `ry-job`
  - `ry-workflow`
- 被谁依赖：
  - `Nacos`
  - `system/resource`
  - 后续 `job/workflow`
- 排障优先级：高。
- 你通常先看它的场景：
  - Nacos 起不来
  - 后端报数据库连接异常
  - 业务表或配置表缺失

### `release-platform-infra-redis-df954c5c7-tjlk2`

- 作用：缓存、登录态、验证码、分布式锁。
- 被谁依赖：
  - `gateway`
  - `auth`
  - `system`
  - `resource`
- 排障优先级：高。
- 你通常先看它的场景：
  - 登录异常
  - 验证码接口异常
  - 服务启动时卡在 Redis 初始化

### `release-platform-infra-kafka-697b444cc-ljzfz`

- 作用：消息基础设施。
- 当前定位：平台预埋能力，当前核心链路不强依赖。
- 排障优先级：中。
- 你通常先看它的场景：
  - 要验证消息链路
  - Kafka 自身探针重启

### `release-platform-infra-nacos-6b655bbb45-cvh76`

- 作用：配置中心 + 注册中心。
- 被谁依赖：
  - `gateway`
  - `auth`
  - `system`
  - `resource`
  - `monitor`
- 排障优先级：最高。
- 你通常先看它的场景：
  - 业务服务启动失败
  - 服务拉不到配置
  - 服务没有注册成功

## 4. apisix

这一层是统一入口层。  
本机 `30080` 的业务访问都先经过这里。

### `apisix-74696ffd89-6dmmc`

- 作用：APISIX 数据面。
- 当前承担：
  - `/` -> 前端
  - `/prod-api/**` -> `gateway`
- 排障优先级：高。
- 你通常先看它的场景：
  - 页面打不开
  - API 入口 404/502/504
  - 路由、重写、限流异常

### `traffic-gateway-ingress-controller-b9cc69ff-cbcb8`

- 作用：APISIX Ingress Controller。
- 为什么存在：监听 `ApisixRoute` 等资源，把规则同步给 APISIX。
- 排障优先级：中高。
- 你通常先看它的场景：
  - 你明明改了路由对象，但 APISIX 行为没变化
  - Controller 日志里可能有同步失败

### `traffic-gateway-external-etcd-5bcfc8476b-4ldr2`

- 作用：APISIX 使用的外部 etcd。
- 为什么存在：APISIX 的配置、路由、插件状态需要持久化。
- 排障优先级：高。
- 你通常先看它的场景：
  - APISIX 起不来
  - ingress-controller 无法同步路由

## 5. ruoyi

这一层是业务服务层。  
如果入口已通，但具体功能异常，主要排这里。

### `ruoyi-backend-ruoyi-backend-gateway-757cb4cb5c-8vdvg`

- 作用：后端统一网关。
- 当前承担：
  - 统一入口后的服务路由
  - 鉴权前置校验
  - 统一横切过滤
- 上游：
  - `APISIX`
- 下游：
  - `auth`
  - `system`
  - `resource`
  - `monitor`
- 排障优先级：最高。
- 你通常先看它的场景：
  - `/prod-api/**` 不通
  - 401/403/404
  - 路由配置异常

### `ruoyi-backend-ruoyi-backend-auth-64c86bc89-nmkhp`

- 作用：认证中心。
- 当前承担：
  - 登录
  - 验证码
  - token 签发
- 依赖：
  - `Nacos`
  - `Redis`
  - `system`
- 排障优先级：最高。
- 你通常先看它的场景：
  - 登录失败
  - 验证码接口异常
  - token 签发异常

### `ruoyi-backend-ruoyi-backend-system-5f975487d8-nwj6c`

- 作用：核心业务服务。
- 当前承担：
  - 用户、角色、菜单、租户、配置等核心能力
- 依赖：
  - `MySQL`
  - `Redis`
  - `Nacos`
- 排障优先级：最高。
- 你通常先看它的场景：
  - 登录后拉用户信息失败
  - 权限、租户、配置相关异常

### `ruoyi-backend-ruoyi-backend-resource-6dd9cc5565-kqfjp`

- 作用：资源服务。
- 当前承担：
  - 文件/资源相关能力
- 依赖：
  - `MySQL`
  - `Redis`
  - `Nacos`
- 排障优先级：中高。
- 你通常先看它的场景：
  - 文件上传/资源访问异常
  - 资源服务单独重启

### `ruoyi-backend-ruoyi-backend-monitor-866c97759f-wd5g4`

- 作用：监控与运维辅助服务。
- 当前状态特征：
  - 这个 Pod 在本地单节点环境里更容易受探针和冷启动影响
  - 之前就出现过 `0/1 Running`、健康检查超时
- 排障优先级：中。
- 你通常先看它的场景：
  - Spring Boot Admin 类能力异常
  - 监控辅助功能不可用
- 备注：
  - 如果核心业务正常，而它单独不稳定，先判断是不是本机资源和探针窗口问题，不要误判成整体集群故障

### `ruoyi-frontend-ruoyi-frontend-8d98596ff-tpsvb`

- 作用：前端静态站点。
- 当前承担：
  - `http://127.0.0.1:30080/` 页面内容
- 上游：
  - `APISIX`
- 排障优先级：高。
- 你通常先看它的场景：
  - 首页打不开
  - 前端静态资源 404
  - 页面白屏但后端 API 正常

## 6. observability

这一层承载指标、日志、链路。

### `kube-prometheus-stack-operator-5c5999c77d-bmtxg`

- 作用：Prometheus Operator。
- 为什么存在：它负责管理 `ServiceMonitor`、`Prometheus`、`Alertmanager` 等 CRD 对象。
- 排障优先级：高。
- 你通常先看它的场景：
  - `ServiceMonitor` 已创建，但 Prometheus 不抓

### `prometheus-kube-prometheus-stack-prometheus-0`

- 作用：Prometheus 实例。
- 当前承担：
  - 抓取 `ruoyi-backend-*`
  - 抓取 `apisix`
  - 抓取 `nacos`
  - 抓取 `alloy`
- 排障优先级：高。
- 你通常先看它的场景：
  - target down
  - 指标断流

### `alertmanager-kube-prometheus-stack-alertmanager-0`

- 作用：Alertmanager。
- 当前定位：告警聚合与通知中心。
- 排障优先级：中。
- 你通常先看它的场景：
  - 后续接告警通知链路时

### `kube-prometheus-stack-grafana-7445c86866-g94hd`

- 作用：Grafana。
- 当前承担：
  - 指标可视化
  - Loki 日志查询入口
- 排障优先级：高。
- 你通常先看它的场景：
  - 页面能打开，但看不到仪表盘数据
  - Loki datasource 异常

### `kube-prometheus-stack-kube-state-metrics-8d79d86d5-2bc9m`

- 作用：采集 Kubernetes 对象状态指标。
- 为什么重要：它让你看到 Deployment、Pod、Node 等资源层面的指标。

### `loki-0`

- 作用：日志存储与查询后端。
- 排障优先级：高。
- 你通常先看它的场景：
  - Grafana 日志面板没数据
  - Alloy 上报失败

### `loki-canary-kgnkh`

- 作用：Loki 自检 Pod。
- 为什么存在：周期性写日志并验证 Loki 查询链路。
- 排障优先级：中。

### `alloy-8lzql`

- 作用：日志采集代理。
- 当前承担：
  - 采集 `ruoyi / infra / apisix` 的 Pod 日志
  - 推送到 Loki
- 排障优先级：高。
- 你通常先看它的场景：
  - 有应用日志，但 Grafana 查不到

### `skywalking-oap-df6b5664d-8b9cm`

- 作用：SkyWalking OAP 后端。
- 当前承担：
  - 接收 Java agent 上报的 trace
  - 提供链路分析数据
- 排障优先级：高。
- 你通常先看它的场景：
  - 服务明明打了 agent，但 UI 没 trace

### `skywalking-ui-59b7b4b78c-vbj2f`

- 作用：SkyWalking 前端界面。
- 当前承担：
  - 链路追踪可视化页面
- 排障优先级：中。
- 你通常先看它的场景：
  - UI 打不开
  - OAP 正常但前端展示异常

## 7. 你排障时的优先级顺序

建议按这个顺序看：

1. `kube-system`
   - 集群是不是活着
2. `infra`
   - `Nacos / MySQL / Redis` 是否稳定
3. `apisix`
   - 入口是否转发正常
4. `ruoyi`
   - 业务服务是否 Ready
5. `observability`
   - 指标、日志、trace 是否完整

如果是页面打不开，优先顺序改成：

1. `apisix`
2. `ruoyi-frontend`
3. `ruoyi-backend-gateway`

如果是登录失败，优先顺序改成：

1. `auth`
2. `gateway`
3. `system`
4. `redis`
5. `nacos`

如果是服务启动失败，优先顺序改成：

1. `nacos`
2. `mysql`
3. 对应业务 Pod 的 `describe` 和 `logs`

## 8. 配套文档

- [访问入口总览表](./04-access-entrypoints.md)
- [组件部署说明](./05-component-deployment-guide.md)
- [K8s 命令行运维手册](./06-k8s-cli-ops-runbook.md)
