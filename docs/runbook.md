# Runbook — deploy, operação e teardown

> Passo a passo para o operador. O repositório inteiro é reconstruível: se a cluster
> sumir, os comandos abaixo a recriam do zero a partir do Git.

## 0. Pré-requisitos

```bash
# ferramentas (já instaladas na máquina de dev)
terraform -v   # 1.9.8+    tflint -v   # 0.53+
kubectl version --client   # kustomize, helm, kubeconform, aws, gh

# credenciais AWS (único segredo humano do projeto)
aws configure   # ou export AWS_PROFILE=...
aws sts get-caller-identity   # precisa responder
```

Sem credenciais da AWS, tudo o resto do repositório continua validando localmente
(`make validate`, `make kubeconform`, `npm test`).

## 1. State remoto (uma única vez por conta)

```bash
make init-backend
# cria: S3 netvision-terraform-state-<suffix> (versionado) + DynamoDB netvision-terraform-locks
```

Se preferir nome próprio: `SUFFIX=meu-nome make init-backend`.

## 2. Infraestrutura

```bash
cd infra/envs/prod
cp terraform.tfvars.example terraform.tfvars   # revisar region/suffix/budget_email
cp backend.hcl.example backend.hcl             # preencher bucket/table do passo 1

make init        # terraform init -backend=false && validate (auto-contido)
make plan        # requer AWS: lê AZs/SGs/SMS parameters
make apply       # VPC, ASG spot, IAM, budget
```

Outputs relevantes: `oidc_role_arn`, `asg_name`, `instance_ids`.

## 3. Nó + k3s (via user_data do ASG)

```bash
make up      # força desired=1; user_data instala k3s v1.31.3+k3s1 (~2-4 min)
make verify  # SSM → k3s kubectl get nodes  (sem SSH, sem chave)
```

`scripts/verify_cluster.sh` descobre a instância pela tag `Name=netvision-k3s` e roda
`k3s kubectl` via `ssm:SendCommand`. Se retornar "cluster não está rodando", o ASG ainda
está quente — aguarde e repita.

## 4. GitOps + plataforma

```bash
make gitops
# scripts/bootstrap_gitops.sh:
#   1. helm upgrade --install argocd (chart 10.9.6) + argocd cli via SSM
#   2. aplica cluster/gitops/root-app.yaml
#   3. root app sincroniza apps/platform-* e apps/workload-*
```

Verificação:

```bash
make verify   # agora deve listar: argocd, ingress-nginx, kube-prometheus-stack,
              # loki, alloy, netvision, demo (pods Running/Ready)
```

## 5. Acessos

```bash
make dashboards   # kubectl port-forward svc/kube-prometheus-stack-grafana 30000:80
# Grafana: admin / (senha no secret kube-prometheus-stack-grafana)

# NetVision direto (sem ingress):
kubectl -n netvision port-forward svc/netvision 8080:8080
curl localhost:8080/healthz
curl localhost:8080/metrics | grep nv_

# ArgoCD UI:
kubectl -n argocd port-forward svc/argocd-server 8081:80
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## 6. CI/CD no GitHub

```bash
# papel OIDC (uma vez):
ROLE_ARN=$(terraform -chdir=infra/envs/prod output -raw oidc_role_arn)
gh variable set AWS_ROLE_ARN --body "$ROLE_ARN"

# em seguida, nos Settings → Actions do repo:
#   - Actions: Read and write permissions (para push em ghcr.io)
gh api repos/anjggti-eng/netvision-platform/actions/permissions/workflow \
  -X PUT -f default_workflow_permissions=write -f can_approve_pull_request_reviews=true
```

Pipeline (`main`): `plan` (OIDC) → `app test` → `docker build` → **Trivy gate** →
push `ghcr.io/anjggti-eng/netvision` → `rollout restart` via SSM (pula se a cluster
estiver fora do ar).

## 7. MikroTik real (opcional)

O app nasce em modo simulado (`SIMULATE=1`). Para apontar num RouterOS:

```bash
kubectl -n netvision create secret generic netvision-mikrotik \
  --from-literal=host=192.168.88.1 --from-literal=user=api \
  --from-literal=password='...'
kubectl -n netvision set env/deployment ... # ou editar o manifesto: SIMULATE=0
```

A `secretKeyRef` do Deployment já é `optional: true` — sem secret, cai no simulador.

## 8. Teardown

```bash
make down    # ASG→0, volume EBS removido; custo volta a ~US$0
```

Para apagar tudo (inclui state remoto — **irá perder o histórico de states**):

```bash
cd infra/envs/prod && terraform destroy
# state remoto: deletar bucket + tabela manualmente ou re-executar init-backend com DESTROY=1
```

## Troubleshooting rápido

| Sintoma | Causa provável | Ação |
|---|---|---|
| `verify` → "cluster não está rodando" | ASG ainda subindo / desired=0 | `make up`, espere 4 min, repita |
| ArgoCD `OutOfSync` eterno | valor do Helm divergente do values | `argocd app diff <app>` / forçar sync na UI |
| `ServiceMonitor` ignorado | label `release:` errada | deve ser `kube-prometheus-stack` |
| Trivy falha no CI | CVE HIGH/CRITICAL **com fix** | atualizar base image ou dependência |
| `terraform plan` pede credenciais | data sources (AZ/SG) exigem API | esperado — sem credenciais use `make validate` |
| Budget alarm e-mail não chegou | inscrição SNS pendente | confirme o link no e-mail do tópico |
