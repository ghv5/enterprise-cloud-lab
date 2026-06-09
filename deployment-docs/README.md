# RuoYi Local Kubernetes Deployment Docs

本目录用于记录本机 Docker Desktop Kubernetes 环境下部署 RuoYi-Cloud-Plus + ruoyi-plus-soybean 的关键过程、架构和配置索引。

## 目录原则

- 只存放轻量 Markdown 文档和小型配置说明。
- 不存放镜像、压缩包、JAR、node_modules、Helm chart 依赖包、数据库 dump、日志文件。
- 不把第三方 Helm chart vendor 到本目录；统一通过 `helm repo add`、`helm pull` 或 Chart dependency 管理。
- 大文件、构建产物和运行数据只存在 Docker/K8s/本地缓存或专门的部署目录中。

## 当前目标

- Kubernetes: Docker Desktop Kubernetes
- 数据库: MySQL
- 日志: Loki + Promtail
- 流量入口: APISIX 作为唯一 Ingress 入口
- 部署管理: Helm 全量管理
- 前端: `../ruoyi-plus-soybean`
- 后端: `../RuoYi-Cloud-Plus`

## 文档索引

1. [部署任务清单](./01-task-checklist.md)
2. [目标部署架构](./02-target-architecture.md)
3. [关键配置文件索引](./03-key-config-index.md)
4. [访问入口总览表](./04-access-entrypoints.md)
5. [组件部署说明](./05-component-deployment-guide.md)
6. [K8s 命令行运维手册](./06-k8s-cli-ops-runbook.md)
7. [当前 Pod 说明文档](./07-pod-inventory.md)
8. [URL 路径视角下的 Pod 关系图](./08-url-path-pod-relationship.md)
9. [K8s 中级运维实战手册](./09-k8s-practical-handbook.md)
