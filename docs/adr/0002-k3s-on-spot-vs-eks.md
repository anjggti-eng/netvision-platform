# ADR-0002: k3s on Spot EC2 instead of EKS

- **Status:** Accepted
- **Date:** 2026-10-01

## Context

The platform needs a real Kubernetes control plane to demonstrate GitOps (ArgoCD),
operators (Prometheus Operator) and workload rollout. Options:

| Option | Control-plane cost | Node cost | Ops burden |
|---|---|---|---|
| **EKS** | US$0.10/h ≈ **US$73/month**, always on | ≥1 × m7g.medium | Managed, but add-ons, IRSA, node groups |
| **k3s on EC2 spot** | US$0 | ~US$0.02/h **only while running** | Single binary, we own upgrades |
| Kind/k3d in CI only | US$0 | US$0 | Not a "cloud" — no AWS story |

EKS alone would blow the US~$5 budget by 15× before a single node boots. Since the
repo's premise is *near-zero cost with real engineering*, EKS is unaffordable by
construction, not by preference.

## Decision

Run **k3s `v1.31.3+k3s1` on an ASG of spot `t4g.medium` (Graviton)** instances, one node,
installed from `user_data`, administered through **AWS SSM** (no SSH keys), with all
cluster state recoverable from Git + remote Terraform state.

## Consequences

**Positive**
- Control plane: US$0. Nodes are the only compute line item, and `make down` removes it.
- Graviton spot ≈ 60–70% cheaper than on-demand x86 for the same cores.
- k3s ships kubelet, containerd, CoreDNS, flannel and Traefik-free defaults in one binary —
  the install is 10 lines of shell we can read.
- ArgoCD re-syncs the whole platform onto a fresh node, which makes spot interruptions a
  non-event.

**Negative / accepted risks**
- **Single node = no HA.** Node loss = downtime until ASG replacement completes.
  Acceptable: this is a portfolio platform, not customer traffic.
- We own k3s/kernel upgrades (documented in the runbook; k3s version pinned).
- Spot can reclaim the instance at 2 minutes' notice.
- EKS-specific features (managed node groups, Fargate, EKS add-ons, IRSA) are out of scope;
  IRSA-style workload IAM would use pod identity in a multi-node evolution.

## Alternatives considered

1. **EKS** — rejected on fixed US$73/month cost.
2. **k3d/Kind in CI** — kept as a *complement* (cheap manifest smoke tests), not the platform.
3. **HashiCorp Nomad / ECS** — would abandon the Kubernetes/GitOps story entirely.
