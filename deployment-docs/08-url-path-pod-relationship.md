# URL 路径视角下的 Pod 关系图

> 观察路径：`GET http://127.0.0.1:30080/prod-api/auth/code`

## 图片

- [URL 路径 Pod 关系图 SVG](./08-url-path-pod-relationship.svg)

## 这张图在看什么

这张图是简化示意图，不写完整 Pod 后缀，只保留足够识别组件的短名。它从一条真实 URL 的访问路径出发，去看：

1. 请求先进入哪个 Pod
2. 路由规则是怎么生效的
3. 业务请求最终落到哪个 Pod
4. 这条主链路依赖哪些中间件 Pod
5. 日志、指标、链路追踪又分别被哪些 Pod 观测

## 主链路

`Browser -> apisix -> ruoyi-backend-gateway -> ruoyi-backend-auth`

其中：

- APISIX 命中 `/prod-api/*`
- 通过 `proxy-rewrite` 把 `/prod-api/auth/code` 改写成 `/auth/code`
- 转发到 `ruoyi-backend-gateway`
- gateway 再把请求路由给 `ruoyi-backend-auth`

## 强依赖 Pod

这条链路里最关键的依赖是：

- `release-platform-infra-nacos-*`
- `release-platform-infra-redis-*`
- `release-platform-infra-mysql-*`

原因：

- `auth/gateway/system` 启动都依赖 Nacos
- 验证码链路依赖 Redis
- Nacos 自己又依赖 MySQL

## 观测 Pod

同一条链路会被这些 Pod 观测：

- `prometheus-*`：抓指标
- `alloy-*`：采日志
- `loki-*`：存日志
- `skywalking-oap-*`：收 trace
- `skywalking-ui-*` / `grafana-*`：做人能看的界面

## 配套文档

- [当前 Pod 说明文档](./07-pod-inventory.md)
- [K8s 命令行运维手册](./06-k8s-cli-ops-runbook.md)
- [访问入口总览表](./04-access-entrypoints.md)
