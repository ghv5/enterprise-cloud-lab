# observability-tracing

本地 Docker Desktop Kubernetes 的轻量 SkyWalking 部署。

## 组成

- `skywalking-oap`: `apache/skywalking-oap-server:9.7.0`
- `skywalking-ui`: `apache/skywalking-ui:9.7.0`

## 设计取舍

- 使用 `H2` 作为 OAP 存储，避免在本地再引入 Elasticsearch。
- 保持 `ClusterIP`，先通过 `port-forward` 验证 tracing，再决定是否挂到 APISIX。
- Java agent 通过 `ruoyi-backend` 的 `initContainer + emptyDir` 注入，不额外维护主机卷。

## 安装

```bash
helm upgrade --install observability-tracing ./deploy/helm/observability-tracing -n observability
```

## 访问

```bash
kubectl -n observability port-forward svc/skywalking-ui 18080:18080
```

浏览器打开 `http://127.0.0.1:18080`。
