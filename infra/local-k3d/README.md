# Local k3d Cluster

This is the recommended first runtime for a 32 GB Mac.

## Resource Target

Set Docker Desktop roughly to:

```text
CPU: 8
Memory: 18-22 GB
Disk: 100 GB+
```

## Cluster Shape

```text
1 k3d server
2 k3d agents
Traefik disabled
Local HTTP entry:  http://127.0.0.1:8080
Local HTTPS entry: https://127.0.0.1:8443
```

## Commands

```bash
infra/local-k3d/create-cluster.sh
infra/local-k3d/install-platform.sh
infra/local-k3d/install-apisix.sh
infra/local-k3d/port-forward-argocd.sh
```

`install-platform.sh` installs Argo CD and Argo Rollouts from local chart
packages in `infra/local-k3d/charts/` to avoid depending on
`raw.githubusercontent.com` during local setup.

Delete the cluster:

```bash
infra/local-k3d/delete-cluster.sh
```
