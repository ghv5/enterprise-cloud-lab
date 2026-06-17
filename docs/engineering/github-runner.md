# GitHub + 本机 CD 方案

当前条件只有 `Mac + GitHub`，因此 CD 方案采用：

- GitHub Actions 做集中编排
- 本机安装 GitHub self-hosted runner
- 本机 runner 负责 `dev/test/prod` 启停

## Runner 标签

建议给本机 runner 打标签：

```text
self-hosted
macOS
enterprise-cloud-lab
```

## 环境映射

- `develop` -> `dev`
- 手工触发 -> 可选 `dev / test / prod`
- `main` -> `prod`

## 注意事项

- `prod` 在当前阶段只是本机生产模拟
- 真正迁移云上后，workflow 不需要重写，只需要替换 runner 与部署脚本
