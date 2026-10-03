# NetVision Platform — Design Spec

**Data:** 2026-10-01 · **Status:** aprovado pelo usuário (design em chat, seções 1–6)
**Objetivo:** repo bandeira monorepo posicionando o perfil anjggti-eng como Cloud/DevOps Engineer, evoluindo o que já existe (NetVision + fiscalguard-pro), sem generalismo.

## 1. Intenção e critérios de sucesso

- **Resultado:** plataforma de observabilidade cloud-native rodando de verdade na AWS, gerenciada por IaC + GitOps, com deploy demonstrável em GIF/README; e perfil GitHub coerente com Cloud/DevOps Engineer.
- **Sucesso (verificável):**
  1. `make up` sobe a plataforma em AWS em <30 min; `make down` deixa custo ≈ US$0.
  2. PR aberto no repo mostra `terraform plan` verde via OIDC (sem chaves estáticas).
  3. Grafana com dashboards reais e 2 alertas Prometheus ativos; alvo Prometheus do NetVision `UP`.
  4. Perfil GitHub: README de perfil novo, headline Cloud/DevOps Engineer, 4 pins alinhados, topics nos 4 repos.
  5. Skill opencode `devops-cloud` instalada e carregável.

## 2. Escopo

**In:** infra Terraform (bootstrap, network, compute spot, budget, OIDC), k3s na AWS, ArgoCD + kube-prometheus-stack + Loki + ingress-nginx, dashboards + 2 alertas, app NetVision containerizada (com simulador), workload demo, Trivy no CI, docs premium (README, Mermaid, ADRs, runbook), profile README + pins/topics, skill devops-cloud.

**Fora (YAGNI):** certificação AWS, blog post, migração real pra EKS, MikroTik físico obrigatório, domínio/TLS próprio, RDS, NAT Gateway, EKS.

## 3. Arquitetura

```
netvision-platform/
├── infra/
│   ├── bootstrap/            # S3 versionado + DynamoDB LockID (state remoto)
│   ├── modules/{network,compute,budget,oidc}
│   └── envs/prod/            # backend.tf + main.tf (compose dos módulos)
├── cluster/
│   ├── gitops/               # ArgoCD root app + app-of-apps
│   ├── platform/             # helm-values, dashboards ConfigMap, PrometheusRules
│   └── workloads/{netvision,demo}/
├── apps/netvision/           # Fastify + prom-client + pino, Dockerfile, Vitest
├── scripts/                  # verify_cluster.sh, checks
├── .github/workflows/ci.yml  # fmt, tflint, validate, plan (PR, OIDC), trivy
├── docs/{architecture.md,adr/,runbook.md,cost.md}
├── Makefile                  # up down validate lint kubeconform dashboards
└── README.md
```

## 4. Decisões técnicas

| Tema | Decisão | Justificativa |
|---|---|---|
| Cloud | AWS `sa-east-1` | mercado BR, latência local |
| Compute | EC2 spot `t4g.medium` (ARM64), ASG, k3s server | custo ≈ US$0; destroy em 1 comando |
| Rede | VPC pública **sem NAT**, SG restritos | evita US$32/mês de NAT; economia é requisito |
| Custo | AWS Budget US$5 → SNS e-mail | guarda de segurança contratada |
| GitOps | ArgoCD app-of-apps | deploy = commit; demostrável |
| Obs | kube-prometheus-stack (ret. 7d) + Loki single-binary | padrão de mercado |
| Alertas | PrometheusRule: NodeCPU >85% 5m; pod Failed >0 2m | prova de operação real |
| App | NetVision → Fastify `/healthz` + `/metrics` (prom-client), pino, coletor MikroTik com `SIMULATE=1` | app sob observação; CI sem hardware |
| CI/CD | GitHub Actions + OIDC (`gha-plan-role`), Trivy image scan | sem segredos no repo |
| Portabilidade | ADR-0001 explica k3s-spot vs EKS + caminho de migração | neutraliza objeção de recrutador |
| Segurança | SG 22/tcp só de `admin_cidr`; sem credenciais estáticas | baseline mínima |

## 5. Interfaces contratuais

- **Terraform (envs/prod outputs):** `vpc_id`, `public_subnet_id`, `sg_cluster_id`, `asg_name`, `k3s_server_ip`, `state_bucket`, `state_lock_table`, `oidc_role_arn`.
- **App NetVision:** `GET /healthz` → 200 `{status:"ok"}`; `GET /metrics` → text/plain com `nv_uplink_in_bytes`/`nv_uplink_out_bytes` (auge por ciclo do coletor, `0` se `SIMULATE=1` sem roteador). Env: `MIKROTIK_HOST`, `MIKROTIK_USER`, `MIKROTIK_PASS`, `SIMULATE`, `PORT` (default 8080).
- **GitOps:** raiz `cluster/gitops/root.yaml` referencia `cluster/platform` e `cluster/workloads/*` como apps do ArgoCD; labels obrigatórias: `app.kubernetes.io/name`, `app.kubernetes.io/part-of: netvision-platform`.
- **Make:** `make up | down | validate | lint | kubeconform | dashboards`.

## 6. Entregáveis fora do repo

1. `anjggti-eng/anjggti-eng` (profile README) — headline: "Cloud/DevOps Engineer | Observability & IaC — AWS, Kubernetes, Terraform".
2. Topics+licença em: `netvision-platform`, `databricks-orchestrator`, `fiscalguard-pro`, `secureshield-`.
3. Checklist manual pro usuário: trocar bio e reordenar pins (API do GitHub não permite).
4. Skill `~/.config/opencode/skills/devops-cloud/SKILL.md`.

## 7. Cronograma (3–4 semanas, execução nesta sessão task a task)

| Semana | Tasks |
|---|---|
| 1 | T1 scaffold+bootstrap · T2 network · T3 compute+k3s · T4 budget+Makefile |
| 2 | T5 CI+OIDC · T6 GitOps+stack · T7 dashboards+alertas |
| 3 | T8 app NetVision · T9 demo+Trivy |
| 4 | T10 docs premium · T11 perfil GitHub · T12 skill devops-cloud |

## 8. Riscos e mitigação

- **Nó k3s não joina (user_data)** → `scripts/verify_cluster.sh` como step de verificação obrigatório (T3).
- **SG aberta** → teste de plan: nada de `0.0.0.0/0` em 22/tcp (T2).
- **Destroy incompleto** → checklist de recursos no `make down` + doc `cost.md` (T4).
- **ArgoCD não reconcilia** → `argocd app wait --healthy` no quickstart (T6).
- **Sem credenciais AWS nesta sessão** → apply fica em passo de handoff; todo o resto valida localmente (`validate`, `tflint`, `kubeconform`, plan com provider fake quando aplicável).
