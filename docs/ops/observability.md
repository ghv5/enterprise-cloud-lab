# 可观测性与排查策略

## 当前能力

- Spring Boot Admin：看服务存活、实例状态、Actuator 端点
- Prometheus：采集指标
- Grafana：统一看板
- Alertmanager：集中告警入口
- requestId + traceId + spanId：日志串联

## 极致排查原则

- 先查 `gateway` 再查下游服务
- 每次排查优先拿到 `requestId`
- 所有服务统一开放：
  - `/actuator/health`
  - `/actuator/prometheus`
  - `/actuator/loggers`
  - `/actuator/threaddump`

## 最短排查路径

1. Grafana 看错误率和流量变化
2. Spring Boot Admin 看实例是否异常
3. 根据响应头 `X-Request-Id` 去对应服务日志检索
4. 必要时看线程栈和实时日志级别
