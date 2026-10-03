# ADR-0001: No NAT Gateway

- **Status:** Accepted
- **Date:** 2026-10-01

## Context

The platform runs a single-node k3s cluster whose workloads are outbound-only consumers
( pulling images, ArgoCD polling GitHub, Alloy → Loki internal traffic, Helm chart fetches).
On AWS, private subnets reach the internet through a NAT Gateway, which costs:

- ~US$0.045/h **always-on** (~US$32/month just for the appliance), plus
- ~US$0.045/GB processed on top.

That single line item would be ~6× the entire budget (US$5) for a cluster that runs a few
hours a day. A second option — VPC endpoints for every needed service (ECR, S3, GitHub…) —
adds 4–5 × ~US$0.01/h endpoint charges and still doesn't cover general HTTPS egress.

## Decision

Put nodes in **public subnets with an Internet Gateway only**. No NAT Gateway, no VPC
endpoints. Outbound traffic is controlled by security groups, not by NAT.

## Consequences

**Positive**
- Infrastructure line item for networking: **US$0**.
- Fewer moving parts to debug (no NAT AZ failover, no endpoint DNS quirks).
- `scripts/check_no_nat.sh` + a tflint-friendly CI guard prevent regressions.

**Negative / accepted risks**
- Instances hold public IPv4 addresses (billed ~US$0.005/h while running — cheaper than
  NAT by two orders of magnitude, and only while the cluster is up).
- The k3s API server and node ports are reachable from the internet — mitigated by
  security groups that only admit the operator's IP for 6443/80/443 and rely on the AWS
  SSM agent for administration (no SSH, no key pair).
- No "private subnet" story to show in the topology. Documented honestly as a cost-driven
  choice, not an oversight.

## Alternatives considered

1. NAT Gateway — rejected on cost (~US$32/month floor).
2. VPC endpoints only — rejected on cost and incomplete egress coverage.
3. Private subnets + SOCKS/bastion — extra VM to babysit, no material gain at this scale.
