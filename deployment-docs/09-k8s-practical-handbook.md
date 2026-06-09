# K8s 中级运维实战手册

> 目标：基于本次 `RuoYi-Cloud-Plus + Docker Desktop Kubernetes + Helm` 的部署实践，整理一份能支撑日常交流、排障、部署和观测的 K8s 中级运维文档。  
> 定位：不是 Kubernetes 官方概念大全，而是“实际会遇到什么、怎么判断、用什么命令、怎么和别人讲清楚”。

## 1. 你需要形成的 K8s 心智模型

Kubernetes 不是“启动容器的工具”，而是一个声明式调度和调谐系统。

你提交的是期望状态：

```text
我要 1 个 gateway
我要 1 个 redis
我要一个 Service 暴露它
我要 readiness 通过后才接流量
我要 PVC 存储数据
我要 Prometheus 自动抓这个服务指标
```

K8s 控制器持续把真实状态调成期望状态：

```text
YAML / Helm values
-> Kubernetes API
-> Controller 调谐
-> Pod / Service / PVC / Endpoint 等对象变化
-> 应用真正可用
```

中级运维的核心能力不是背对象字段，而是能沿着这条链路定位：

```text
声明是否正确
对象是否创建
Pod 是否调度
容器是否启动
探针是否通过
Service 是否有 Endpoints
入口是否转发
依赖是否可达
指标/日志/trace 是否能观测
```

## 2. 本次环境的对象地图

当前实践环境按 namespace 分层：

| Namespace | 职责 | 核心对象 |
|---|---|---|
| `kube-system` | K8s 控制面、DNS、网络、存储 | `coredns`、`etcd`、`kube-apiserver`、`kube-proxy` |
| `infra` | 中间件 | MySQL、Redis、Kafka、Nacos |
| `apisix` | 流量入口 | APISIX、Ingress Controller、APISIX etcd |
| `ruoyi` | 业务应用 | gateway、auth、system、resource、monitor、frontend |
| `observability` | 可观测 | Prometheus、Grafana、Loki、Alloy、SkyWalking |

这套环境里的典型请求链路：

```text
Browser
-> NodePort 30080
-> APISIX
-> ruoyi-gateway
-> ruoyi-auth / ruoyi-system
-> Redis / MySQL / Nacos
-> Prometheus / Loki / SkyWalking 观测
```

## 3. 高频概念说明

### 3.1 Namespace

Namespace 是资源隔离边界，适合按职责分层。

本环境的用法：

- `infra` 放基础中间件
- `ruoyi` 放业务服务
- `apisix` 放流量入口
- `observability` 放监控日志链路

常见误区：

- Namespace 不是强安全边界，安全隔离还要靠 RBAC、NetworkPolicy、Secret 管理。
- Service 跨 namespace 访问要写完整 DNS，例如 `release-platform-infra-nacos.infra.svc.cluster.local`。

### 3.2 Pod

Pod 是 K8s 最小调度单元，不是长期稳定身份。

你要记住：

- Pod 会被删除和重建
- Pod IP 会变化
- 不应该直接依赖 Pod IP
- 访问应用应该走 Service

排障时先看：

```bash
k get pod -n <ns> -o wide
k describe pod -n <ns> <pod>
k logs -n <ns> <pod> --tail=200
```

### 3.3 Deployment

Deployment 管理无状态应用，负责滚动发布和副本维持。

本环境中的例子：

- `ruoyi-backend-ruoyi-backend-gateway`
- `ruoyi-backend-ruoyi-backend-auth`
- `apisix`
- `release-platform-infra-nacos`

常用命令：

```bash
k rollout restart deployment -n ruoyi ruoyi-backend-ruoyi-backend-auth
k rollout status deployment -n ruoyi ruoyi-backend-ruoyi-backend-auth
k rollout history deployment -n ruoyi ruoyi-backend-ruoyi-backend-auth
```

### 3.4 ReplicaSet

ReplicaSet 是 Deployment 背后的副本控制器。

一般不直接改 ReplicaSet。你看到它，通常是为了判断：

- 当前 Deployment 对应哪个版本
- 滚动升级时新旧 ReplicaSet 是否并存
- 旧 ReplicaSet 是否残留

```bash
k get rs -n ruoyi
```

### 3.5 StatefulSet

StatefulSet 管理有状态服务，Pod 名称和存储相对稳定。

本环境中的例子：

- `loki-0`
- `prometheus-kube-prometheus-stack-prometheus-0`
- `alertmanager-kube-prometheus-stack-alertmanager-0`

适合：

- 数据库
- 消息队列
- 存储系统
- 需要稳定身份的服务

### 3.6 DaemonSet

DaemonSet 保证每个节点运行一份 Pod。

本环境中的例子：

- `alloy`

典型用途：

- 日志采集
- 节点监控
- 网络插件
- 安全 agent

### 3.7 Service

Service 是稳定访问入口，负责把流量转到后端 Pod。

常见类型：

| 类型 | 用途 |
|---|---|
| `ClusterIP` | 集群内访问，默认类型 |
| `NodePort` | 通过节点端口暴露给宿主机 |
| `LoadBalancer` | 云环境中接云负载均衡 |
| `Headless` | 不分配 ClusterIP，常用于 StatefulSet |

本环境中的例子：

- `apisix` 使用 `NodePort 30080`
- `nacos` 使用 `NodePort 30848`
- `grafana` 使用 `NodePort 30300`

### 3.8 Endpoints

Endpoints 是 Service 真正转发到哪些 Pod 的结果。

如果 Service 存在但访问不通，必须看 Endpoints：

```bash
k get svc -n ruoyi
k get endpoints -n ruoyi
```

高频结论：

- Service 有，Endpoints 为空：selector 不匹配或 Pod 没 Ready。
- Endpoints 有，但请求不通：端口、协议、应用监听地址或 NetworkPolicy 问题。

### 3.9 Ingress 与 Ingress Controller

Ingress 是规则，Ingress Controller 是执行规则的人。

本环境中：

- 前端使用标准 `Ingress`
- `ingressClassName: apisix`
- APISIX Ingress Controller 监听后同步给 APISIX

重要理解：

```text
Ingress YAML 本身不转发流量
真正转发的是 Ingress Controller / Gateway
```

### 3.10 CRD

CRD 是自定义资源类型。

本环境中的例子：

- `ApisixRoute`
- `ApisixPluginConfig`
- `ServiceMonitor`

这些不是 K8s 原生资源，而是由对应 operator/controller 解释执行。

排障思路：

```text
CRD 对象存在
-> controller 是否正常
-> status 是否 Accepted / Ready
-> 最终系统是否同步成功
```

### 3.11 ConfigMap

ConfigMap 放非敏感配置。

本环境中的例子：

- Nacos 外置配置
- Grafana datasource
- Alloy 日志采集配置

常见问题：

- ConfigMap 改了，Pod 不一定自动重启
- 通过环境变量注入的配置，需要重启 Pod 才生效

### 3.12 Secret

Secret 放敏感配置。

本环境中的例子：

- Grafana admin 密码
- Actuator Basic Auth

注意：

- K8s Secret 默认只是 base64，不等于强加密。
- 不要在文档和日志里随意打印明文。
- 生产环境需要接外部密钥系统或加密存储。

### 3.13 PVC / PV / StorageClass

PVC 是应用对存储的申请，PV 是实际存储资源，StorageClass 是动态供应策略。

本环境中：

- MySQL、Nacos、Loki、Prometheus 等需要持久化。
- Docker Desktop 使用本地存储 provisioner。

排障先看：

```bash
k get pvc -A
k describe pvc -n <ns> <pvc>
k get storageclass
```

### 3.14 Probe

Probe 是 K8s 判断应用状态的机制。

| Probe | 作用 |
|---|---|
| `startupProbe` | 判断应用是否完成启动 |
| `readinessProbe` | 判断是否可以接流量 |
| `livenessProbe` | 判断是否需要重启容器 |

本次部署中，Nacos、Kafka、Java 服务都遇到过启动慢问题。  
中级运维必须能判断“应用真的挂了”还是“探针太紧”。

典型现象：

```text
Startup probe failed
Readiness probe failed
Liveness probe failed
context deadline exceeded
connection refused
```

处理原则：

- 启动慢：加大 `startupProbe.failureThreshold`
- 依赖慢：先保证依赖启动顺序和重试机制
- 应用卡死：看线程、CPU、内存和日志
- 不要直接把 liveness 关掉掩盖问题

### 3.15 Resources

Resources 决定 Pod 的调度和运行上限。

| 字段 | 含义 |
|---|---|
| `requests.cpu` | 调度时预留 CPU |
| `requests.memory` | 调度时预留内存 |
| `limits.cpu` | CPU 上限 |
| `limits.memory` | 内存上限，超过可能 OOMKilled |

本次部署中，Java 服务和 observability 组件对内存敏感。  
Docker Desktop 单节点环境尤其容易出现：

- 启动慢
- OOM
- probe 超时
- Pod 反复重启

### 3.16 Label / Selector

Label 是对象标签，Selector 根据标签选择对象。

Service、Deployment、ServiceMonitor 都依赖 label/selector。

高频问题：

- Service selector 写错，Endpoints 为空。
- ServiceMonitor selector 写错，Prometheus 不抓。

### 3.17 RBAC

RBAC 控制谁能访问哪些 K8s 资源。

核心对象：

- `ServiceAccount`
- `Role`
- `ClusterRole`
- `RoleBinding`
- `ClusterRoleBinding`

本环境中，Prometheus Operator、APISIX Ingress Controller 都需要权限读取资源对象。

### 3.18 DNS

K8s 内部 DNS 格式：

```text
<service>.<namespace>.svc.cluster.local
```

本环境例子：

```text
release-platform-infra-nacos.infra.svc.cluster.local
kube-prometheus-stack-prometheus.observability.svc.cluster.local
skywalking-oap.observability.svc.cluster.local
```

高频问题：

- 应用配置还写 `localhost`
- namespace 写错
- CoreDNS 异常

### 3.19 Helm

Helm 是包管理器，也是这套环境的声明式部署入口。

你要能讲清：

```text
Chart.yaml 定义包
values.yaml 定义参数
templates/ 渲染 K8s YAML
helm install/upgrade 应用到集群
helm rollback 回滚历史版本
```

本环境的 Helm 分层：

- `platform-infra`
- `traffic-gateway`
- `ruoyi-backend`
- `ruoyi-frontend`
- `observability-addons`
- `observability-tracing`

## 4. 高频故障问题

### 4.1 Pod Pending

常见原因：

- 资源不足
- PVC 未绑定
- nodeSelector / affinity 不满足
- taint/toleration 不匹配
- 镜像拉取前置 Secret 不存在

命令：

```bash
k describe pod -n <ns> <pod>
k get events -A --sort-by=.metadata.creationTimestamp | tail -n 100
```

重点看 Events。

### 4.2 ImagePullBackOff / ErrImagePull

常见原因：

- 镜像名错
- tag 不存在
- 私有仓库缺少 imagePullSecret
- 本地镜像在 Docker Desktop K8s 中不可见

命令：

```bash
k describe pod -n <ns> <pod>
k get pod -n <ns> <pod> -o jsonpath='{.spec.containers[*].image}'
```

### 4.3 CrashLoopBackOff

含义：容器启动后退出，K8s 反复重启。

命令：

```bash
k logs -n <ns> <pod> --previous --tail=200
k describe pod -n <ns> <pod>
```

常见原因：

- 启动参数错
- 配置缺失
- 依赖不可达
- 数据库初始化失败
- JVM 内存参数不合理

### 4.4 OOMKilled

含义：容器超过 memory limit，被内核杀掉。

命令：

```bash
k describe pod -n <ns> <pod> | grep -A8 "Last State"
k top pod -n <ns>
```

处理：

- 增加 memory limit
- 降低 JVM `-Xmx`
- 减少副本或关闭非核心组件
- 排查内存泄漏

### 4.5 Probe 失败

常见表现：

- `connection refused`
- `context deadline exceeded`
- `HTTP probe failed with statuscode: 503`

判断：

- `connection refused`：应用端口没起来
- `timeout`：应用卡住或启动慢
- `503`：应用已启动但还没 ready

处理：

- 给慢启动服务加 `startupProbe`
- 放宽 `failureThreshold`
- 不要把 readiness 和 liveness 用成同一个强杀开关

### 4.6 Service 无法访问

排查链路：

```bash
k get svc -n <ns>
k get endpoints -n <ns>
k describe svc -n <ns> <svc>
```

常见原因：

- selector 不匹配
- Pod 不 Ready
- targetPort 错
- 应用没有监听 `0.0.0.0`

本次实际案例：

- Grafana 外部 Service 最初 targetPort 配错，后修正为容器实际监听端口。

### 4.7 Ingress / APISIX 规则不生效

排查链路：

```bash
k get ingress -A
k get apisixroute -A
k get apisixpluginconfig -A
k logs -n apisix deployment/traffic-gateway-ingress-controller --tail=200
k logs -n apisix deployment/apisix --tail=200
```

关键判断：

- `ingressClassName` 是否正确
- `ApisixRoute.status` 是否 Accepted
- ingress-controller 是否能访问 APISIX admin
- APISIX 依赖的 etcd 是否正常

### 4.8 Nacos 正常启动但业务拉不到配置

排查：

```bash
k logs -n ruoyi deployment/ruoyi-backend-ruoyi-backend-auth --tail=300 | grep "Load config"
k logs -n infra deployment/release-platform-infra-nacos --tail=200
```

重点：

- `dataId`
- `group`
- namespace / tenant
- 用户名密码
- `spring.config.import`

### 4.9 Prometheus target down

排查：

```bash
k get servicemonitor -A
k get svc -A
k describe servicemonitor -n <ns> <name>
```

重点：

- ServiceMonitor selector 是否匹配 Service label
- endpoint path 是否正确
- Basic Auth Secret 是否存在
- 应用是否暴露 `/actuator/prometheus`

### 4.10 Grafana 没数据

排查：

- datasource 是否存在
- Prometheus target 是否 up
- Loki 是否有 label
- 查询时间范围是否正确

命令：

```bash
curl -s http://127.0.0.1:30300/api/health
k logs -n observability deployment/kube-prometheus-stack-grafana --tail=200
```

### 4.11 Loki 查不到日志

排查：

```bash
k logs -n observability daemonset/alloy --tail=200
k logs -n observability statefulset/loki --tail=200
```

重点：

- Alloy 是否采到目标 namespace
- Loki 是否写入正常
- label 是否符合查询条件

### 4.12 SkyWalking 没 trace

排查：

```bash
k logs -n observability deployment/skywalking-oap --tail=200
k logs -n ruoyi deployment/ruoyi-backend-ruoyi-backend-gateway --tail=200
```

重点：

- Java 服务是否带 `-javaagent`
- OAP 地址是否正确
- 服务是否真的产生请求
- agent 是否被镜像或 initContainer 正确注入

### 4.13 Helm upgrade 失败

常见原因：

- 资源已存在，但没有 Helm ownership annotation
- CRD 未安装
- values 类型不匹配
- 模板渲染失败

命令：

```bash
helm lint ./deploy/helm/ruoyi-backend
helm template ruoyi-backend ./deploy/helm/ruoyi-backend -n ruoyi
helm status ruoyi-backend -n ruoyi
helm history ruoyi-backend -n ruoyi
```

## 5. 高频运维命令

### 5.1 初始化别名

```bash
export KUBECTL_BIN=/Applications/Docker.app/Contents/Resources/bin/kubectl
alias k="$KUBECTL_BIN"
alias h="helm"
```

### 5.2 集群巡检

```bash
k get nodes -o wide
k get ns
k get pods -A -o wide
k get svc -A
k get pvc -A
k get events -A --sort-by=.metadata.creationTimestamp | tail -n 100
```

### 5.3 异常筛选

```bash
k get pods -A | egrep -v 'Running|Completed'
k get pods -A --field-selector=status.phase=Pending
```

### 5.4 Pod 详情

```bash
k describe pod -n <ns> <pod>
k logs -n <ns> <pod> --tail=200
k logs -n <ns> <pod> --previous --tail=200
k exec -it -n <ns> <pod> -- sh
```

### 5.5 Deployment 操作

```bash
k get deploy -n <ns>
k rollout restart deployment -n <ns> <deploy>
k rollout status deployment -n <ns> <deploy>
k rollout history deployment -n <ns> <deploy>
k scale deployment -n <ns> <deploy> --replicas=0
k scale deployment -n <ns> <deploy> --replicas=1
```

### 5.6 Service 与 Endpoints

```bash
k get svc -n <ns>
k get endpoints -n <ns>
k describe svc -n <ns> <svc>
```

### 5.7 配置和密钥

```bash
k get configmap -A
k get secret -A
k describe configmap -n <ns> <name>
k describe secret -n <ns> <name>
```

### 5.8 Helm

```bash
helm list -A
helm status <release> -n <ns>
helm get values <release> -n <ns>
helm get manifest <release> -n <ns>
helm upgrade --install <release> <chart-path> -n <ns>
helm history <release> -n <ns>
helm rollback <release> <revision> -n <ns>
```

### 5.9 端口转发

```bash
k port-forward -n observability svc/kube-prometheus-stack-prometheus 9090:9090
k port-forward -n infra svc/release-platform-infra-nacos 8848:8848
```

### 5.10 资源用量

```bash
k top nodes
k top pods -A
```

如果 `top` 不可用，通常是没装 `metrics-server`。

## 6. 高频插件与生态组件

### 6.1 Helm

- 作用：K8s 包管理。
- 本环境用途：所有组件统一安装、升级、回滚。
- 高频关注：values、模板渲染、release 状态、资源 ownership。

### 6.2 APISIX Ingress Controller

- 作用：把 `Ingress / ApisixRoute / ApisixPluginConfig` 同步成 APISIX 路由。
- 本环境用途：统一业务入口、路径重写、限流。
- 高频关注：route accepted、admin API、etcd、rewrite、plugin。

### 6.3 Prometheus Operator

- 作用：用 CRD 管理 Prometheus、Alertmanager、ServiceMonitor。
- 本环境用途：抓业务、APISIX、Nacos、Alloy 指标。
- 高频关注：ServiceMonitor selector、target up/down、Basic Auth。

### 6.4 Grafana

- 作用：指标、日志、链路入口的可视化面板。
- 本环境用途：查看 Prometheus 指标和 Loki 日志。
- 高频关注：datasource、dashboard、时间范围、变量。

### 6.5 Loki + Alloy

- 作用：日志采集和查询。
- 本环境用途：Alloy 采集 Pod stdout，Loki 存储，Grafana 查询。
- 高频关注：采集范围、label、写入错误、查询时间范围。

### 6.6 SkyWalking

- 作用：分布式链路追踪。
- 本环境用途：Java agent 上报 gateway/auth/system/resource 调用链。
- 高频关注：agent 注入、OAP 地址、服务名、请求是否真实发生。

### 6.7 kube-state-metrics

- 作用：暴露 K8s 对象状态指标。
- 本环境用途：让 Prometheus 看到 Deployment、Pod、Service 等状态。
- 高频关注：对象状态是否能在 Grafana 展示。

### 6.8 metrics-server

- 作用：提供节点和 Pod 实时资源指标。
- 用途：支持 `kubectl top` 和 HPA。
- 当前说明：如果 `k top` 不可用，优先检查 metrics-server。

### 6.9 cert-manager

- 作用：自动签发和续期 TLS 证书。
- 当前环境未接入。
- 中级运维要知道：生产 HTTPS 入口通常会配它。

### 6.10 Argo CD

- 作用：GitOps 持续交付。
- 当前环境未接入。
- 中级运维要知道：生产中常用 Git 作为集群声明式状态来源。

### 6.11 Velero

- 作用：K8s 资源和卷备份恢复。
- 当前环境未接入。
- 中级运维要知道：生产集群升级、迁移、灾备会用到。

### 6.12 Cilium / Calico

- 作用：CNI 网络插件和 NetworkPolicy 实现。
- Docker Desktop 有自己的默认网络实现。
- 中级运维要知道：生产网络策略、服务可达性、Pod IP 路由都和 CNI 强相关。

### 6.13 KEDA / HPA

- `HPA`：按 CPU/内存或自定义指标扩缩容。
- `KEDA`：按事件源扩缩容，例如 Kafka lag。
- 当前环境没有重点接入，但生产弹性伸缩经常会用。

### 6.14 常用 CLI 辅助工具

| 工具 | 用途 |
|---|---|
| `k9s` | 终端 UI 查看 K8s |
| `stern` | 多 Pod 聚合日志 |
| `kubectx` | 快速切换 context |
| `kubens` | 快速切换 namespace |
| `jq` | 处理 JSON 输出 |
| `yq` | 处理 YAML 输出 |

## 7. 中级运维交流时要讲得清楚的问题

### 7.1 一个请求进来之后怎么走

以本环境为例：

```text
NodePort 30080
-> APISIX
-> ApisixRoute / Ingress 规则匹配
-> gateway
-> auth/system/resource
-> Redis/MySQL/Nacos
```

你要能说清：

- 入口在哪里
- 路由规则在哪里
- Service 怎么找到 Pod
- 哪些依赖会影响请求成功
- 如何从日志、指标、trace 观察它

### 7.2 Pod 为什么 Running 但服务不可用

常见答案：

- readiness 没通过
- Service 没有 endpoints
- 应用内部健康检查失败
- 依赖服务不可达
- 入口路由没转到它
- 端口配置错

### 7.3 为什么 Helm 状态 deployed 但业务还是坏的

因为 Helm 只说明资源提交成功，不等于应用业务成功。

还要看：

- Pod Ready
- Service Endpoints
- 应用日志
- 探针
- 依赖连通性
- 业务接口验证

### 7.4 为什么要分 namespace

为了职责清晰、权限边界、资源查询和运维隔离。

本环境分层：

- 中间件独立
- 业务独立
- 流量入口独立
- 可观测独立

### 7.5 为什么不能手工改运行中资源

因为这套环境由 Helm 管理。

手工改可能导致：

- 与 values 不一致
- 下次 upgrade 被覆盖
- Helm ownership 冲突
- 排障时不知道真实来源

正确方式：

```text
改 values/template
-> helm upgrade
-> 验证集群状态
```

### 7.6 什么叫声明式运维

声明式运维关注“目标状态”。

不是手工进入容器改配置，而是：

```text
配置写进 values / ConfigMap / Secret
用 Helm 渲染
交给 K8s controller 调谐
用观测系统验证结果
```

## 8. 一套标准排障路径

### 8.1 从用户现象开始

例如：页面打不开。

```text
浏览器打不开
-> curl 入口
-> 看 APISIX
-> 看 frontend/gateway
-> 看 Service/Endpoints
-> 看 Pod logs/describe
-> 看依赖 infra
-> 看指标/日志/trace
```

### 8.2 从 Pod 异常开始

```text
Pod 非 Ready
-> describe 看 Events
-> logs 看应用错误
-> previous logs 看上次崩溃
-> 看依赖服务
-> 看资源限制
-> 看 probes
```

### 8.3 从指标异常开始

```text
Prometheus target down
-> ServiceMonitor
-> Service label
-> Endpoints
-> Pod readiness
-> 指标 path/auth
```

### 8.4 从日志异常开始

```text
Grafana 查不到日志
-> Alloy 是否采集
-> Loki 是否写入
-> label 是否匹配
-> Pod 是否输出 stdout
```

## 9. 本次实践沉淀的关键经验

### 9.1 本机 K8s 要放宽慢启动组件的探针

Nacos、Kafka、Java 服务都可能因为冷启动慢被探针误杀。

合理做法：

- 加 `startupProbe`
- readiness 和 liveness 区分职责
- 根据服务启动时间设置 failureThreshold

### 9.2 中间件先稳定，业务再启动

本次环境的真实依赖顺序：

```text
MySQL
-> Nacos
-> Redis / Kafka
-> gateway/auth/system/resource
-> APISIX
-> observability
```

业务服务问题，很多时候根因在 Nacos、MySQL、Redis。

### 9.3 Service targetPort 很容易配错

Grafana 外部访问曾经因为 targetPort 错而不可用。

判断口诀：

```text
Service port 是别人访问它的端口
targetPort 是容器真正监听的端口
nodePort 是宿主机访问节点的端口
```

### 9.4 Helm 是事实来源

所有可重复部署的配置都应回到 Chart：

- values
- template
- Secret
- Service
- ServiceMonitor
- NodePort

不要依赖手工 `kubectl edit`。

### 9.5 可观测要覆盖三件事

```text
Metrics：Prometheus
Logs：Alloy + Loki
Traces：SkyWalking
```

三者关注点不同：

- 指标告诉你“哪里不正常”
- 日志告诉你“当时发生了什么”
- 链路告诉你“请求经过了哪里”

## 10. 中级掌握标准

达到中级 K8s 运维水平，至少要能做到：

1. 能解释 Pod、Deployment、Service、Ingress、ConfigMap、Secret、PVC、Probe 的作用。
2. 能从 `kubectl get pods -A` 判断集群大致健康度。
3. 能用 `describe/logs/events` 定位 80% 的 Pod 启动问题。
4. 能判断 Service 不通是 selector、endpoints、端口还是应用问题。
5. 能解释 Helm values/template/release 的关系。
6. 能做一次安全的 `helm upgrade` 和 `helm rollback`。
7. 能解释 Ingress Controller 和 Ingress 资源不是一回事。
8. 能排查 Prometheus target down。
9. 能说明日志、指标、链路追踪分别解决什么问题。
10. 能根据业务链路画出入口、服务、中间件、观测之间的关系。

## 11. 配套文档

- [K8s 命令行运维手册](./06-k8s-cli-ops-runbook.md)
- [当前 Pod 说明文档](./07-pod-inventory.md)
- [URL 路径视角下的 Pod 关系图](./08-url-path-pod-relationship.md)
- [组件部署说明](./05-component-deployment-guide.md)
- [访问入口总览表](./04-access-entrypoints.md)
