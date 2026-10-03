# Cost model

Budget guardrail: **AWS Budget de US$5/mês** → alarme SNS
(`infra/modules/budget`, cobrado por `var.budget_amount`).

> Todos os valores de EC2/IPv4 são **estimativas** para `sa-east-1`/spot e variam com o
> preço corrente da AWS. Trate a tabela como ordem de grandeza, não como fatura.

## Enquanto o cluster está no ar (`make up` … `make down`)

| Item | Estimativa | Observação |
|---|---|---|
| EC2 spot `t4g.medium` | ~US$0,02/h | Graviton; `t4g.large` no fallback do ASG custa ~2× |
| IPv4 público (por instância em execução) | ~US$0,005/h | Cobrado desde 2024 — some ~US$0,005/h |
| EBS gp3 20 GB | ~US$0,03/dia | **Apagado por `make down`** (volume não é preservado) |
| NLB do ingress-nginx | ~US$0,025/h + LCU | Só existe enquanto a cluster roda |
| S3 (state) + DynamoDB (lock) | < US$0,10/mês | Versionamento barato em estado pequeno |
| CloudWatch/SNS (budget) | centavos | 1 métrica + 1 tópico |

**Sessão típica de 3 h: ≈ US$0,15–0,25** (EC2 + IPv4 + NLB, sem considerar descontos/ free tier).

## Ocioso (`make down` feito)

| Item | Custo |
|---|---|
| EC2 / IPv4 / NLB / EBS | **US$0** (ASG em 0, volume deletado) |
| S3 + DynamoDB | < US$0,10/mês |
| **Total ocioso** | **≈ US$0** |

## O que deliberadamente NÃO existe

| Serviço | Custo que evitamos | Alternativa usada |
|---|---|---|
| NAT Gateway | ~US$32/mês + US$0,045/GB | Subpública + IGW ([ADR-0001](adr/0001-no-nat-gateway.md)) |
| EKS | US$73/mês fixos | k3s no spot ([ADR-0002](adr/0002-k3s-on-spot-vs-eks.md)) |
| RDS | dezenas de US$/mês | app sem banco (state é Git + S3) |
| EIP parado | US$0,005/h por EIP não anexado | sem EIPs criados à mão |

## Alarmes

- `aws_budgets_budget` → **US$5/mês**, notificação em 80% e 100% via SNS
  (`var.budget_email`). Confirme a inscrição no e-mail na primeira criação do tópico.
- Alertas de Prometheus (`nv-node-high-cpu`, `nv-pod-down`) são de *sanidade*, não de custo.

## Rotina de economia

1. Trabalhou na plataforma? `make up`.
2. Terminou? `make down` — some EC2, IPv4, NLB e EBS.
3. Deixe o GitHub Actions cuidando do resto (CI é gratuito em repositórios públicos).
4. Uma vez por mês: olhe o e-mail do budget alarm.
