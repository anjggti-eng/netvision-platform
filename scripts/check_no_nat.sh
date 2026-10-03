#!/usr/bin/env bash
# Review Focus #2: o plano NÃO pode conter NAT Gateway nem 22/tcp aberto ao mundo.
# Uso: terraform -chdir=infra/envs/prod plan -out=tfplan && scripts/check_no_nat.sh infra/envs/prod/tfplan
set -euo pipefail

PLAN_FILE="${1:-infra/envs/prod/tfplan}"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "FAIL: plano não encontrado em $PLAN_FILE (rode terraform plan antes)" >&2
  exit 1
fi

JSON=$(terraform show -json "$PLAN_FILE")

if echo "$JSON" | grep -qi 'nat_gateway\|aws_nat_gateway'; then
  echo "FAIL: plano contém NAT Gateway (proibido — custo US$32/mês)" >&2
  exit 1
fi

OPEN_22=$(echo "$JSON" | python3 -c '
import json,sys
plan=json.load(sys.stdin)
bad=0
for rc in plan.get("resource_changes",[]):
    if "aws_security_group" not in rc.get("type",""): continue
    for a in rc.get("change",{}).get("after",{}).get("ingress",[]) or []:
        if 22 in (a.get("from_port",0),) or a.get("from_port",0)<=22<=a.get("to_port",22):
            for c in a.get("cidr_blocks",[]) or []:
                if c=="0.0.0.0/0": bad+=1
print(bad)
')

if [[ "$OPEN_22" != "0" ]]; then
  echo "FAIL: porta 22/tcp aberta para 0.0.0.0/0 em $OPEN_22 regra(s)" >&2
  exit 1
fi

echo "PASS: sem NAT Gateway e sem 22/tcp aberto ao mundo"
