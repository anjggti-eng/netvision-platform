# NetVision Platform

[![CI](https://github.com/anjggti-eng/netvision-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/anjggti-eng/netvision-platform/actions/workflows/ci.yml)
![Terraform](https://img.shields.io/badge/Terraform-1.9-7B42BC?logo=terraform&logoColor=white)
![k3s](https://img.shields.io/badge/k3s-v1.31-4C9F38?logo=kubernetes&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-v3.5-EF7B4D?logo=argo&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-%E2%89%A52.0-E6522C?logo=prometheus&logoColor=white)

**A production-shaped observability platform on near-zero AWS cost** — Terraform, a
single-node k3s cluster on Spot `t4g.medium` (Graviton), GitOps with ArgoCD, and a full
metrics/logs/alerting stack. Deployed with `make up`, torn down with `make down`.

Built to answer one question honestly: *how far can you go on a US$5 budget without
cutting the engineering?* No NAT Gateway, no EKS, no RDS — and no shortcuts in the
pipeline either: OIDC (zero static keys), Trivy gates, kubeconform on every manifest.

## Architecture

```
                        GitHub (main)
              ┌───────────────┴───────────────┐
              │  CI: tf plan (OIDC) │ app test │
              │  trivy gate │ push ghcr      │
              └───────┬───────────────┬───────┘
                      │               │ ArgoCD polls
   ┌──────────────────▼───┐    ┌──────▼──────────────────────────┐
   │  AWS sa-east-1       │    │  k3s cluster (spot t4g.medium)  │
   │                      │    │                                 │
   │  VPC 10.42.0.0/16    │    │  argocd ──► app-of-apps         │
   │  ├─ public subnet a  │    │   ├─ ingress-nginx (LoadBalancer│
   │  ├─ public subnet c  │◄───┤   ├─ kube-prometheus-stack       │
   │  └─ no NAT gateway   │ssh │   ├─ loki + alloy                │
   │  EC2 spot + IGW only │via │   ├─ netvision (app)             │
   │  SSM (no SSH key)    │SSM │   └─ demo (whoami + loadgen)     │
   │  budget alarm US$5   │    │                                 │
   └──────────────────────┘    └─────────────────────────────────┘
```

- **Ingress**: nginx-ingress with a Service of type `LoadBalancer` (AWS NLB, billed only while the cluster is up).
- **Metrics**: kube-prometheus-stack scrapes the NetVision app via `ServiceMonitor`; two alert rules + two Grafana dashboards ship with the repo.
- **Logs**: Alloy (Grafana Agent) → Loki; the demo workload generates real traffic so dashboards are never empty.
- **GitOps**: one root `Application` → ArgoCD discovers `cluster/gitops/apps/*` → platform + workloads. What you see in Git is what runs.

## Repository layout

| Path | What it is |
|---|---|
| `infra/bootstrap/` | Remote state: S3 (versioned) + DynamoDB lock |
| `infra/modules/{network,compute,budget,oidc}` | VPC without NAT · spot ASG + k3s · cost alarm · GitHub OIDC role |
| `infra/envs/prod/` | The one environment, wired to the modules |
| `cluster/gitops/` | ArgoCD root app + app-of-apps |
| `cluster/platform/` | Applications + Helm values (ingress, Prometheus, Loki, Alloy) |
| `cluster/platform/monitoring/` | Alert rules (PrometheusRule) + Grafana dashboards |
| `cluster/workloads/{netvision,demo}` | The observable app + traffic generator |
| `apps/netvision/` | TypeScript/Fastify app exposing `nv_uplink_*` metrics (MikroTik or simulated) |
| `scripts/` | `check_no_nat.sh`, `verify_cluster.sh` (SSM, no SSH), `bootstrap_gitops.sh` |
| `docs/` | Architecture, ADRs, runbook, cost model |

## Quickstart

**Local (no AWS account needed):**

```bash
make validate      # tflint + terraform fmt/validate + secret guard
make kubeconform   # every manifest, strict
cd apps/netvision && npm test   # 3/3 vitest
```

**Deploy (≈ US$0.06 for a 3-hour session, ~US$0 idle):**

```bash
make init-backend  # one-time: S3 + DynamoDB for state
make init && make plan && make apply
make up            # ASG + k3s on spot
make verify        # nodes via SSM — no SSH, no keys
make gitops        # ArgoCD + platform stack
make dashboards    # Grafana on :3000 via port-forward
make down          # everything billable gone
```

Full walkthrough with GitHub OIDC setup: [`docs/runbook.md`](docs/runbook.md).

## Cost model

| Component | While cluster is up | Idle |
|---|---|---|
| EC2 `t4g.medium` spot (sa-east-1) | ~US$0.02/h (estimate) | US$0 |
| Public IPv4 (running instances) | ~US$0.005/h | US$0 |
| EBS 20 GB gp3 | ~US$0.03/day (estimate) | US$0 (volume persists — `make down` deletes it) |
| NAT Gateway | **not used** | — |
| EKS control plane | **not used** | — |
| S3 + DynamoDB (state) | < US$0.10/month | < US$0.10/month |

A **US$5 budget alarm** (`infra/modules/budget`) is the hard stop. Details: [`docs/cost.md`](docs/cost.md).

## Security posture

- **No static AWS credentials anywhere** — CI assumes an IAM role via GitHub OIDC; the repo has a dedicated secret-scan guard (`no-static-secrets` job).
- **No SSH** — node access is `ssm:StartSession` only; the verify/bootstrap scripts drive k3s through SSM Run Command.
- **Trivy gates every image** (HIGH/CRITICAL with a fix = build failure).
- **kubeconform strict** on every manifest, on every PR.
- Runtime container: non-root, read-only rootfs, dropped capabilities, no npm in the final image.

## Docs

- [`docs/architecture.md`](docs/architecture.md) — components and data flow
- [`docs/adr/0001-no-nat-gateway.md`](docs/adr/0001-no-nat-gateway.md) — why there is no NAT
- [`docs/adr/0002-k3s-on-spot-vs-eks.md`](docs/adr/0002-k3s-on-spot-vs-eks.md) — why not EKS
- [`docs/runbook.md`](docs/runbook.md) — deploy/teardown runbook (PT-BR)
- [`docs/cost.md`](docs/cost.md) — cost model and the US$5 alarm

## License

MIT
