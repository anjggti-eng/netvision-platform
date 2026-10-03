# Architecture

## Goals

1. **Near-zero cost** — every billable AWS feature had to justify itself (NAT: no; EKS: no; RDS: no).
2. **Real GitOps** — the cluster's desired state is entirely in this repo; hand-edits are drift.
3. **Observability as the product** — the platform itself is monitored; the demo app exists to make the dashboards honest.
4. **Zero standing credentials** — humans and CI both reach AWS through roles, never keys.

## Component map

### Infrastructure (`infra/`)

| Module | Responsibility | Notable choice |
|---|---|---|
| `bootstrap` | S3 bucket (versioning) + DynamoDB lock table for Terraform state | Created once, out-of-band, by `make init-backend` |
| `network` | VPC `10.42.0.0/16`, 2 public subnets, IGW, security groups | **No NAT gateway** ([ADR-0001](adr/0001-no-nat-gateway.md)) |
| `compute` | Launch template, mixed-instances spot ASG (`t4g.medium`/`t4g.large`), IAM instance profile, user_data installs k3s `v1.31.3+k3s1` | Graviton/ARM64; access via SSM only |
| `budget` | AWS Budgets action → SNS at **US$5** | Hard stop, not a dashboard you forget |
| `oidc` | GitHub OIDC provider + role `netvision-gh-oidc` | `plan`/`read` in CI; `ssm:SendCommand` for rollouts; explicit `Deny` on `ec2:Create*`/`Delete*`/`Terminate*` |

### Cluster (`cluster/`)

```
gitops/                      ← root Application + app-of-apps (the GitOps entry point)
├── root-app.yaml            ← points ArgoCD at cluster/gitops/apps/
└── apps/
    ├── argocd-self.yaml     ← (bootstrap: ArgoCD itself via Helm)
    ├── platform-net.yaml    ← namespaces + platform bundle
    └── netvision-app.yaml   ← the workload bundle
platform/
├── applications/            ← 4 ArgoCD Applications (Helm): ingress-nginx,
│                              kube-prometheus-stack, loki, alloy
├── helm-values/             ← pinned chart values (91.9.0 / 4.15.1 / 7.3.0 / 1.13.0)
└── monitoring/              ← PrometheusRules + Grafana dashboards (configMapGenerator)
workloads/
├── netvision/               ← Deployment + Service + ServiceMonitor (label release: kube-prometheus-stack)
└── demo/                    ← whoami (2 réplicas) + loadgen (tráfego a cada 2s)
```

**Sync flow:** push to `main` → ArgoCD root app detects commit → app-of-apps syncs the 6 leaf Applications → Helm renders → cluster converges. PRs never touch the cluster (CI runs `terraform plan` + `kubeconform` only).

### Application (`apps/netvision/`)

Fastify 5 (Node 22, ESM, TypeScript strict):

- `GET /healthz` → `{status:"ok", simulate, uptime}` — also the container healthcheck.
- `GET /metrics` → Prometheus registry: `nv_uplink_in_bytes`, `nv_uplink_out_bytes`,
  `nv_uplink_status`, `nv_collector_ticks_total`, `nv_collector_errors_total` + default Node metrics.
- **Collectors** behind one `Collector` interface:
  - `simulator.ts` (default) — deterministic-ish random walk for demo/CI;
  - `mikrotik.ts` — RouterOS REST (`/rest/interface`, Basic Auth) reading absolute `rx-byte`/`tx-byte` counters, 5s timeout. Credentials come from the optional `netvision-mikrotik` Secret.
- `buildApp()` performs the **first tick before resolving**, so `/metrics` is never empty at startup.
- Container: multi-stage build, `npm prune --omit=dev`, npm CLI stripped from the final image, non-root, read-only rootfs.

### Data flow

```
mikrotik (or simulator)
   │  Collector.read()
   ▼
NetVision /metrics  ──ServiceMonitor(15s)──►  Prometheus
                                │                   │
                                │            alert rules (PrometheusRule)
                                ▼                   ▼
                           Grafana ◄──────── Alertmanager
                                ▲
        alloy ──► loki ◄────────┘   (logs from demo/loadgen + platform)
```

## Failure & cost behavior

- **Cluster stopped (`make down`)**: ASG → 0, EBS deleted, NLB gone → cost ≈ S3/DynamoDB pennies. CI degrades gracefully: the rollout step detects "no running instance" and skips with a notice.
- **Spot interruption**: ASG replaces the node; k3s rejoins from user_data; ArgoCD re-syncs everything from Git (state lives in Git + S3, never on the node).
- **Single node = no HA** — accepted trade-off ([ADR-0002](adr/0002-k3s-on-spot-vs-eks.md)); the GitOps/observability design generalizes to multi-node unchanged.
