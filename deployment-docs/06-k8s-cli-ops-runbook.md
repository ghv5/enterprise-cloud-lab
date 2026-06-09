# K8s 命令行运维手册

> 目标：给当前这套 `Docker Desktop Kubernetes + Helm + RuoYi` 环境一份可直接复制执行的命令行运维文档。  
> 适用范围：`infra / apisix / observability / ruoyi`

## 1. 前提

当前机器上 `kubectl` 不一定在默认 `PATH` 中。  
本机可直接使用 Docker Desktop 自带二进制：

```bash
export KUBECTL_BIN=/Applications/Docker.app/Contents/Resources/bin/kubectl
alias k="$KUBECTL_BIN"
```

建议同时准备：

```bash
alias h="helm"
alias kga="k get all"
alias kgp="k get pods"
alias kgs="k get svc"
alias kgsec="k get secret"
alias kgcm="k get configmap"
```

如果需要长期使用，把这些别名写进 `~/.zshrc`。

## 2. 当前命名空间与 Helm Release

```bash
h list -A
k get ns
```

当前环境重点 namespace：

- `infra`：MySQL、Redis、Kafka、Nacos
- `apisix`：APISIX、ingress-controller、external etcd
- `observability`：Prometheus、Grafana、Loki、Alloy、SkyWalking
- `ruoyi`：gateway、auth、system、resource、monitor、frontend

## 3. 全局巡检

### 3.1 看整体健康度

```bash
k get pods -A -o wide
k get svc -A
k get pvc -A
h list -A
```

重点看：

- Pod 是否 `Running` / `Completed`
- `READY` 是否满额，例如 `1/1`、`2/2`
- `RESTARTS` 是否持续增加
- PVC 是否 `Bound`
- Helm release 是否 `deployed`

### 3.2 快速筛出异常 Pod

```bash
k get pods -A | egrep -v 'Running|Completed'
```

### 3.3 看最近事件

```bash
k get events -A --sort-by=.metadata.creationTimestamp | tail -n 100
```

重点看：

- `Unhealthy`
- `BackOff`
- `FailedScheduling`
- `OOMKilled`
- `FailedMount`

## 4. Pod 排障固定套路

对于任何异常 Pod，先按这个顺序：

```bash
k get pod -n <namespace> <pod-name> -o wide
k describe pod -n <namespace> <pod-name>
k logs -n <namespace> <pod-name> --tail=200
k logs -n <namespace> <pod-name> --previous --tail=200
```

判断重点：

1. `describe` 看事件和探针
2. `logs` 看应用报错
3. `--previous` 看上一次重启前日志
4. `State / Last State / Exit Code / Restart Count`

常见结论：

- `Exit Code 137`：通常是 OOM
- `Exit Code 143`：通常是被探针或手工终止
- `connection refused`：依赖服务未起来或端口错误
- `context deadline exceeded`：探针太紧、服务太慢、网络连不通

## 5. 按层排障命令

## 5.1 Kubernetes 基础层

### 看节点和系统组件

```bash
k get nodes -o wide
k get pods -n kube-system
```

重点看：

- `docker-desktop` 是否 `Ready`
- `coredns` 是否正常
- `kube-apiserver`、`etcd` 是否正常

### 常用修复

```bash
k rollout restart deployment -n <namespace> <deployment>
k delete pod -n <namespace> <pod-name>
```

适用场景：

- 配置已更新但 Pod 没重建
- Pod 卡死且 Deployment 会自动拉起新实例

## 5.2 Helm 层

### 看 release

```bash
h list -A
h status release -n infra
h status traffic-gateway -n apisix
h status kube-prometheus-stack -n observability
h status ruoyi-backend -n ruoyi
```

### 看渲染结果

```bash
h get values ruoyi-backend -n ruoyi
h get manifest ruoyi-backend -n ruoyi
```

### 升级与回滚

```bash
h upgrade --install ruoyi-backend ./deploy/helm/ruoyi-backend -n ruoyi
h history ruoyi-backend -n ruoyi
h rollback ruoyi-backend <revision> -n ruoyi
```

高频问题：

- 资源已存在，但不是 Helm 管理
- values 改了，忘了 `upgrade`
- release `deployed`，但 Pod 实际探针失败

## 5.3 infra 层

### MySQL

```bash
kgp -n infra
k logs -n infra deployment/release-platform-infra-mysql --tail=200
k exec -it -n infra deployment/release-platform-infra-mysql -- mysql -uruoyi -pruoyi123 -e "show databases;"
```

常看：

- 是否有 `ry-cloud`、`ry-config`、`ry-job`、`ry-workflow`
- 用户是否允许 `%` 来源访问

验证授权：

```bash
k exec -it -n infra deployment/release-platform-infra-mysql -- mysql -uroot -proot123 -e "SELECT user,host FROM mysql.user;"
```

### Redis

```bash
k logs -n infra deployment/release-platform-infra-redis --tail=100
k exec -it -n infra deployment/release-platform-infra-redis -- redis-cli -a redis123 ping
```

常看：

- `PONG`
- 是否有认证失败

### Kafka

```bash
k logs -n infra deployment/release-platform-infra-kafka --tail=200
k describe pod -n infra $(k get pods -n infra -l app.kubernetes.io/name=kafka -o jsonpath='{.items[0].metadata.name}')
```

常看：

- 是否成功进入 `READY`
- 是否是探针过早导致反复重启

### Nacos

```bash
k logs -n infra deployment/release-platform-infra-nacos --tail=300
k describe pod -n infra $(k get pods -n infra -l app.kubernetes.io/name=nacos -o jsonpath='{.items[0].metadata.name}')
```

连通性验证：

```bash
k exec -it -n infra deployment/release-platform-infra-nacos -- sh -c "wget -qO- http://127.0.0.1:8848/nacos/v1/console/health/liveness"
```

高频问题：

- `No DataSource set`
- `Host 'x.x.x.x' is not allowed to connect`
- `application-common.yml` 已导入，但服务没注册，通常是 `group/dataId` 对不上

## 5.4 APISIX 流量层

### 查看组件

```bash
kgp -n apisix
kgs -n apisix
k get ApisixRoute -A
```

### 看日志

```bash
k logs -n apisix deployment/apisix --tail=200
k logs -n apisix deployment/traffic-gateway-ingress-controller --tail=200
k logs -n apisix deployment/traffic-gateway-external-etcd --tail=200
```

### 验证入口

```bash
curl -I http://127.0.0.1:30080/
curl -I http://127.0.0.1:30080/prod-api/auth/code
curl -s http://127.0.0.1:30080/prod-api/auth/code | head
```

高频问题：

- 前端可达，后端 `404`：通常是 route 或 rewrite 错
- APISIX 起不来：通常先看 etcd 是否 Ready
- `401`：通常是 gateway 鉴权生效，不是 APISIX 自身故障

## 5.5 ruoyi 业务层

### 看全部业务 Pod

```bash
kgp -n ruoyi -o wide
```

### 分别看核心服务日志

```bash
k logs -n ruoyi deployment/ruoyi-backend-ruoyi-backend-gateway --tail=200
k logs -n ruoyi deployment/ruoyi-backend-ruoyi-backend-auth --tail=200
k logs -n ruoyi deployment/ruoyi-backend-ruoyi-backend-system --tail=200
k logs -n ruoyi deployment/ruoyi-backend-ruoyi-backend-resource --tail=200
k logs -n ruoyi deployment/ruoyi-backend-ruoyi-backend-monitor --tail=200
k logs -n ruoyi deployment/ruoyi-frontend-ruoyi-frontend --tail=100
```

### 看 Nacos 配置是否拉到

日志里重点搜：

- `Load config[dataId=ruoyi-*.yml, group=DEFAULT_GROUP] success`
- `Load config[dataId=application-common.yml, group=DEFAULT_GROUP] success`

### 看服务启动慢还是依赖失败

```bash
k describe pod -n ruoyi <pod-name>
```

重点看：

- `Startup probe failed`
- `Readiness probe failed`
- `OOMKilled`
- `connection refused`

### 当前已知案例

当前 `monitor` 曾出现过：

- `0/1 Running`
- `liveness/readiness` 超时
- 启动日志能看到 Nacos 配置拉取成功，但 Undertow 初始化慢

这种情况优先判断：

1. 是不是 Java 服务冷启动慢
2. 探针是不是过紧
3. 是否存在资源不足

## 5.6 observability 层

### Prometheus

```bash
kgp -n observability
k port-forward -n observability svc/kube-prometheus-stack-prometheus 9090:9090
```

浏览器访问：

- `http://127.0.0.1:9090/query`

如果只用命令行，先看 targets 状态：

```bash
k logs -n observability prometheus-kube-prometheus-stack-prometheus-0 -c prometheus --tail=100
```

重点看：

- `ruoyi-backend-*`
- `apisix-prometheus-metrics`
- `release-platform-infra-nacos`
- `alloy`

### Grafana

```bash
curl -s http://127.0.0.1:30300/api/health
kgsec -n observability | grep grafana
```

### Loki / Alloy

```bash
k logs -n observability daemonset/alloy --tail=200
k logs -n observability statefulset/loki --tail=200
```

重点看：

- Alloy 是否在采集 `ruoyi / infra / apisix`
- Loki 是否写入正常

### SkyWalking

```bash
kgp -n observability | egrep 'skywalking'
k logs -n observability deployment/skywalking-oap --tail=200
k logs -n observability deployment/skywalking-ui --tail=100
```

高频关注：

- OAP 是否先起来
- 业务服务是否真的带了 agent
- trace 没出现时，先看业务服务容器环境变量和 JVM 参数

## 6. Service、Endpoints、DNS 排查

### 看 Service 和 Endpoints

```bash
k get svc -A
k get endpoints -A
```

重点看：

- Service 是否存在
- Endpoints 是否为空

如果 Service 有，Endpoints 为空，通常是：

- selector 不匹配
- Pod 没 Ready

### 集群内 DNS 验证

```bash
k exec -it -n ruoyi deployment/ruoyi-backend-ruoyi-backend-gateway -- sh
```

进入容器后：

```bash
getent hosts release-platform-infra-nacos.infra.svc.cluster.local
getent hosts release-platform-infra-redis.infra.svc.cluster.local
```

如果容器没有 `getent`，就改用应用日志判断连通性。

## 7. 配置、Secret、ConfigMap 排查

### 看配置对象

```bash
kgcm -A
kgsec -A
```

### 查看具体内容

```bash
k get configmap -n infra release-platform-infra-nacos-config -o yaml
k get secret -n ruoyi ruoyi-actuator-basic-auth -o yaml
```

如果是 Secret，建议只确认键名和挂载关系，不要到处打印明文。

### 查看 Pod 实际注入环境变量

```bash
k exec -it -n ruoyi deployment/ruoyi-backend-ruoyi-backend-auth -- env | sort
```

适合验证：

- Nacos 地址
- Redis 地址
- JVM 参数
- 端口

## 8. 常用重启与修复命令

### 重启单个 Deployment

```bash
k rollout restart deployment -n ruoyi ruoyi-backend-ruoyi-backend-auth
k rollout status deployment -n ruoyi ruoyi-backend-ruoyi-backend-auth
```

### 直接删 Pod 触发重建

```bash
k delete pod -n ruoyi <pod-name>
```

### 重新应用 Helm

```bash
h upgrade --install release ./deploy/helm/platform-infra -n infra
h upgrade --install traffic-gateway ./deploy/helm/traffic-gateway -n apisix
h upgrade --install ruoyi-backend ./deploy/helm/ruoyi-backend -n ruoyi
h upgrade --install ruoyi-frontend ./deploy/helm/ruoyi-frontend -n ruoyi
```

### 停止一整层

```bash
h uninstall ruoyi-backend -n ruoyi
h uninstall ruoyi-frontend -n ruoyi
```

## 9. 高频排障场景

### 场景 1：页面打不开

先看：

```bash
curl -I http://127.0.0.1:30080/
kgp -n apisix
kgp -n ruoyi
```

排查顺序：

1. APISIX Pod 是否正常
2. 前端 Pod 是否正常
3. `ApisixRoute` 是否存在
4. NodePort `30080` 是否还在

### 场景 2：验证码接口 500/404

先看：

```bash
curl -i http://127.0.0.1:30080/prod-api/auth/code
k logs -n ruoyi deployment/ruoyi-backend-ruoyi-backend-gateway --tail=200
k logs -n ruoyi deployment/ruoyi-backend-ruoyi-backend-auth --tail=200
```

排查重点：

- gateway 路由是否转发成功
- auth 是否完成 Nacos 配置拉取
- Redis 是否可达

### 场景 3：Nacos 正常，但业务服务拉不到配置

```bash
k logs -n ruoyi deployment/ruoyi-backend-ruoyi-backend-system --tail=300 | grep "Load config"
k logs -n infra deployment/release-platform-infra-nacos --tail=200
```

排查重点：

- `dataId`
- `group`
- 用户名密码
- Nacos 地址

### 场景 4：Pod 一直重启

```bash
k describe pod -n <namespace> <pod-name>
k logs -n <namespace> <pod-name> --previous --tail=200
```

优先判断：

- OOM
- 探针太紧
- 依赖未就绪
- 配置错误

### 场景 5：Prometheus target down

```bash
k get servicemonitor -A
k get svc -n ruoyi
k describe servicemonitor -n ruoyi
```

排查重点：

- Service label 是否匹配 `ServiceMonitor`
- 指标端点是否开启
- Basic Auth Secret 是否存在

## 10. 推荐的日常命令组合

### 组合 1：开工前巡检

```bash
h list -A
k get pods -A
k get svc -A
k get events -A --sort-by=.metadata.creationTimestamp | tail -n 50
```

### 组合 2：只盯业务层

```bash
kgp -n ruoyi -w
```

另开一个终端：

```bash
k logs -n ruoyi deployment/ruoyi-backend-ruoyi-backend-gateway -f
```

### 组合 3：只盯入口层

```bash
kgp -n apisix -w
k logs -n apisix deployment/apisix -f
```

### 组合 4：只盯可观测层

```bash
kgp -n observability -w
k logs -n observability daemonset/alloy -f
```

## 11. 宿主机访问地址

详细地址见：

- [访问入口总览表](./04-access-entrypoints.md)

当前常用：

- 前端：`http://127.0.0.1:30080/`
- API：`http://127.0.0.1:30080/prod-api`
- Nacos：`http://127.0.0.1:30848/nacos/`
- Grafana：`http://127.0.0.1:30300/`
- Prometheus：`http://127.0.0.1:30900/`
- SkyWalking UI：`http://127.0.0.1:30081/`
