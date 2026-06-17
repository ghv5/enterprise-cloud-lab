# 运行手册

## 本地启动

```bash
mvn -B -ntp verify
make dev-up
make smoke
```

## 本地停止

```bash
make dev-down
```

## 常见故障

### 1. Gateway 健康但业务接口失败

- 查 `user-service` 和 `order-service` 是否已注册到 Admin
- 查对应服务日志
- 查网关路由配置是否指向正确端口

### 2. Prometheus 抓不到指标

- 确认服务端口正常
- 确认 `/actuator/prometheus` 可访问
- 确认 `host.docker.internal` 在 Docker Desktop 可用

### 3. 本机端口冲突

- 修改 `ops/environments/*.env`
- 重启对应环境

## 回滚

当前阶段回滚方式是：

1. 停止目标环境
2. 切回上一个 Git commit
3. 重新执行 `stack-up.sh`

后续迁移到真正线上时，应升级为镜像版本回滚。
