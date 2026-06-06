# Three-Node K3s Plan

## Server Sizing

Start with:

- 3 nodes, each 4 vCPU / 8 GB RAM / 100 GB SSD.
- Ubuntu 22.04 or 24.04 LTS.
- Public access only for SSH and HTTP/HTTPS.

Upgrade to 4 vCPU / 16 GB RAM if Prometheus, Loki, or SkyWalking need more
headroom.

## Node Roles

```text
node-1: k3s server, Argo CD, APISIX ingress path
node-2: k3s server, sample apps, Redis or other lightweight middleware
node-3: k3s server, Prometheus, Grafana, Loki, database if needed
```

Use labels after cluster creation:

```bash
kubectl label node node-1 lab/role=gateway
kubectl label node node-2 lab/role=apps
kubectl label node node-3 lab/role=observability
```

## Suggested Security Group

```text
22/tcp    SSH, restrict to your IP
80/tcp    HTTP
443/tcp   HTTPS
6443/tcp  K3s API, restrict to your IP and cluster node IPs
```

Avoid exposing Argo CD, Prometheus, Grafana, APISIX Admin, or Kubernetes API to
the public internet without authentication and IP restrictions.
