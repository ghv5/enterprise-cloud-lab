# GitHub R&D Flow Diagram

这张图解描述当前项目基于 GitHub 的最小研发闭环，重点是 `CI`、`Preview Deploy`、合并前验证，以及 `PR closed` 触发的自动销毁。

```mermaid
flowchart TD
    A[Developer creates branch] --> B[Commit and push]
    B --> C[Open or update Pull Request]

    C --> D[GitHub Actions: CI]
    D --> D1[checkout]
    D1 --> D2[setup Java 17]
    D2 --> D3[mvn verify]

    C --> E[GitHub Actions: Preview Deploy]
    E --> E1[package JAR artifacts]
    E1 --> E2[build service images]
    E2 --> E3[push images to GHCR]
    E3 --> E4[copy compose file to local host]
    E4 --> E5[SSH to local Mac runner host]
    E5 --> E6[docker-compose pull]
    E6 --> E7[docker-compose up -d]
    E7 --> E8[PR preview environment available]

    D3 --> F{Checks passed?}
    E8 --> F
    F -->|No| G[Fix code and push again]
    G --> C
    F -->|Yes| H[Code review]
    H --> I[Merge PR]

    I --> J[Main branch remains releasable]

    C --> K{PR closed?}
    K -->|Yes| L[GitHub Actions: destroy-preview]
    L --> L1[SSH to local Mac runner host]
    L1 --> L2[docker-compose down --remove-orphans]
    L2 --> L3[remove preview directory]
    L3 --> M[Preview environment cleaned up]
```

## Reading Guide

- `CI` 负责快速验证代码和构建是否通过。
- `Preview Deploy` 负责验证这次 PR 能否以接近真实部署的方式运行起来。
- `Code Review` 发生在 `CI + Preview` 都给出足够信号之后。
- `PR closed` 不论是否合并，都会触发预览环境销毁，避免本机残留容器和目录。

## Current Mapping

- CI workflow: [.github/workflows/ci.yml](/Users/mac/pspace/github/enterprise-cloud-lab/.github/workflows/ci.yml)
- Preview workflow: [.github/workflows/preview.yml](/Users/mac/pspace/github/enterprise-cloud-lab/.github/workflows/preview.yml)
- Runner notes: [docs/engineering/github-runner.md](/Users/mac/pspace/github/enterprise-cloud-lab/docs/engineering/github-runner.md)
