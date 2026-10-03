# NetVision Platform — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repo bandeira monorepo (Terraform + k3s spot AWS + GitOps + Observabilidade + NetVision containerizada) + reposição do perfil GitHub + skill opencode `devops-cloud`.

**Architecture:** Abordagem A aprovada — VPC pública sem NAT, ASG EC2 spot com k3s, ArgoCD como GitOps, kube-prometheus-stack + Loki, app NetVision como workload observada, CI com `terraform plan` via OIDC.

**Tech Stack:** Terraform ≥1.6, k3s, ArgoCD, Helm (kube-prometheus-stack, ingress-nginx, loki-stack), GitHub Actions, TypeScript/Vitest (app), Docker, Trivy.

**Spec:** `docs/superpowers/specs/2026-10-01-netvision-platform-design.md`

## Global Constraints
- Custo ≈ US$0: **proibido** NAT Gateway, EKS, RDS; budget alarm US$5 obrigatório.
- Região AWS: `sa-east-1`; spot `t4g.medium` (ARM64).
- Todo YAML validado com `kubeconform`; todo Terraform com `fmt -check` + `tflint` + `validate`.
- Nenhum segredo em repo: OIDC no GitHub Actions, state em S3+DynamoDB.
- Licença MIT + topics nos repos criados neste ciclo.

## Review Focus
1. user_data do k3s não joina → step: `scripts/verify_cluster.sh` pós-appply.
2. SG 22/tcp aberta ao mundo → step: plan sem `0.0.0.0/0` em 22/tcp.
3. `make down` incompleto → step: checklist de recursos remanescentes.
4. ArgoCD não reconcilia → step: `argocd app wait --healthy`.
5. Custo real → step: billing < US$5 após 24h.

---

### Task 1: Scaffold do repo + state bootstrap
**Files:** Create: `Makefile`, `.gitignore`, `LICENSE`, `README.md`, `.tflint.hcl`, `infra/bootstrap/{main.tf,variables.tf,outputs.tf}`
**Interfaces:** Produces: `state_bucket`, `state_lock_table` (backend da Task 2).

- [ ] Scaffold de diretórios conforme estrutura da spec §3
- [ ] `infra/bootstrap`: S3 versionado (bloqueio público) + DynamoDB `LockID`
- [ ] `terraform -chdir=infra/bootstrap init && validate` → PASS
- [ ] Commit `chore: scaffold repo + remote state bootstrap`

### Task 2: Módulo network (VPC pública, sem NAT)
**Files:** Create: `infra/modules/network/{main.tf,variables.tf,outputs.tf}`, `infra/envs/prod/{main.tf,backend.tf,variables.tf,outputs.tf,terraform.tfvars.example}`
**Interfaces:** Produces: `vpc_id`, `public_subnet_id`, `sg_cluster_id`. Consome: outputs do bootstrap.

- [ ] Escrito antes do código: teste `scripts/check_no_nat.sh` (grep no plan por `nat_gateway`) e asserção de plan: nenhum `0.0.0.0/0` em porta 22
- [ ] Módulo network: VPC 10.0.0.0/16, 1 subnet pública, IGW, route table, SG (22/tcp só de `admin_cidr`; 6443/10250/80/443 internos)
- [ ] `make validate` (fmt+tflint+validate) → PASS; `terraform plan` com credenciais fake OK e sem NAT
- [ ] Commit `feat(infra): network module without NAT`

### Task 3: Módulo compute (ASG spot k3s)
**Files:** Create: `infra/modules/compute/{main.tf,user_data.sh,outputs.tf}`, `scripts/verify_cluster.sh`
**Interfaces:** Produces: `asg_name`, `k3s_server_ip`. Consome: subnet/SG da Task 2.

- [ ] Teste: `scripts/verify_cluster.sh` (ssh + `k3s kubectl get nodes` não vazio) — falha vermelha documentada sem cluster
- [ ] Launch template `t4g.medium` spot + ASG(1) com user_data: install k3s server, token persistido, firewall 6443/10250
- [ ] `make validate` + plan → PASS
- [ ] Apply + verify (HANDOFF: requer AWS creds)
- [ ] Commit `feat(infra): spot ASG running k3s`

### Task 4: Budget alarm + Makefile
**Files:** Create: `infra/modules/budget/main.tf`, `Makefile`
**Interfaces:** Produces: `make up|down|validate|lint|kubeconform|dashboards`.

- [ ] Módulo budget: AWS Budgets US$5 → SNS + e-mail
- [ ] Makefile com alvos da spec §5
- [ ] `make validate` → PASS
- [ ] Commit `feat(infra): cost budget alarm + make targets`

### Task 5: CI — PR com terraform plan via OIDC
**Files:** Create: `.github/workflows/ci.yml`, `infra/modules/oidc/{main.tf,variables.tf,outputs.tf}`
**Interfaces:** Produces: `oidc_role_arn`.

- [ ] Teste: grep no workflow por `AWS_SECRET_ACCESS_KEY` → vazio
- [ ] OIDC provider + role (read state, ec2 describe, ssm para SSM params se necessário)
- [ ] Workflow: fmt -check, tflint, validate, plan (PR), trivy fs
- [ ] Commit `ci: terraform plan on PR via OIDC`

### Task 6: GitOps — ArgoCD + platform stack
**Files:** Create: `cluster/gitops/{root.yaml,kustomization.yaml}`, `cluster/platform/{kustomization.yaml,ingress-nginx-values.yaml,kube-prometheus-values.yaml,loki-values.yaml}`
**Interfaces:** Labels `app.kubernetes.io/part-of: netvision-platform` (spec §5).

- [ ] Teste: `kustomize build` de cada dir | `kubeconform -strict` (instalar kubeconform no setup)
- [ ] Root app + apps de platform (helm via ArgoCD or raw manifests + values)
- [ ] Apply no cluster real (HANDOFF pós Task 3)
- [ ] Commit `feat(gitops): argocd + observability platform stack`

### Task 7: Dashboards + 2 alertas reais
**Files:** Create: `cluster/platform/dashboards/{node.json,pods.json}`, `cluster/platform/alerts/{node-high-cpu.yaml,pod-down.yaml}`
**Interfaces:** Produces: PrometheusRule `nv-platform`; ConfigMap label `grafana_dashboard: "1"`.

- [ ] Teste: kubeconform nos YAMLs + contagem de 2 PrometheusRules com `severity`
- [ ] Regras: `NodeCPUUsage > 85%` 5m (warning); `Failed pod > 0` 2m (critical)
- [ ] Verificação em cluster (HANDOFF)
- [ ] Commit `feat(obs): dashboards + alert rules`

### Task 8: NetVision app containerizada
**Files:** Create: `apps/netvision/{package.json,tsconfig.json,vitest.config.ts,src/{server.ts,metrics.ts,collector/mikrotik.ts,collector/simulator.ts},Dockerfile,.dockerignore,tests/server.test.ts}`, `cluster/workloads/netvision/{kustomization.yaml,deployment.yaml,service.yaml,servicemonitor.yaml}`
**Interfaces:** Produces: `GET /healthz`, `GET /metrics` com `nv_uplink_*` (spec §5).

- [ ] Teste (Vitest): `/healthz` 200; `/metrics` contém `nv_uplink_in_bytes` após tick do coletor
- [ ] Implementar Fastify + pino + coletor (simulador default)
- [ ] `npm test` → PASS; `docker build` + run + curl → PASS
- [ ] Manifestos no cluster (HANDOFF)
- [ ] Commit `feat(app): netvision observable service`

### Task 9: Demo workload + Trivy de imagem
**Files:** Create: `cluster/workloads/demo/{kustomization.yaml,deployment.yaml,service.yaml}`; Modify: `.github/workflows/ci.yml` (+ build + `trivy image --exit-code 1 --severity HIGH,CRITICAL`)
**Interfaces:** Consome: imagem da Task 8.

- [ ] Demo: app echo com `/metrics` (nginx + exporter ou app node mínima)
- [ ] CI: trivy image gate → PASS em build limpo
- [ ] Commit `feat: demo workload + image scanning`

### Task 10: Docs premium
**Files:** Create: `README.md` (final), `docs/architecture.md`, `docs/adr/0001-k3s-spot-vs-eks.md`, `docs/adr/0002-no-nat.md`, `docs/runbook.md`, `docs/cost.md`, `.markdownlint.json`
**Interfaces:** README referencia `make up`, custo, GIF, diagrama.

- [ ] README: badges, diagrama Mermaid, quickstart, tabela de custo, GIF placeholder
- [ ] ADRs + runbook + cost
- [ ] Verificação: links relativos existem → PASS
- [ ] Commit `docs: architecture, ADRs, runbook, premium README`

### Task 11: Perfil GitHub
**Files:** Create: repo `anjggti-eng/anjggti-eng/README.md`
**Interfaces:** Headline e pins conforme spec §6.

- [ ] Profile README (headline, featured NetVision Platform, badges, slot certificação)
- [ ] `gh repo create` + push → página renderiza
- [ ] `gh repo edit` topics nos 4 repos + license onde falt
- [ ] Checklist manual (bio + pins) entregue ao usuário
- [ ] Verificação: `gh api users/anjggti-eng` coerente

### Task 12: Skill opencode `devops-cloud`
**Files:** Create: `~/.config/opencode/skills/devops-cloud/SKILL.md` (via customize-opencode)
**Interfaces:** Skill listável no opencode.

- [ ] SKILL.md: padrões Terraform/K8s/GitOps/obs/FinOps + checklist de review
- [ ] Verificação: skill carrega no opencode
