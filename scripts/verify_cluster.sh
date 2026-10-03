#!/usr/bin/env bash
# Teste do Task 3: falha se o cluster k3s não estiver Ready.
# Descobre a instância via EC2 API, executa `k3s kubectl get nodes` via SSM
# (sem SSH, sem par de chaves) e monta ./kubeconfig local.
set -euo pipefail

REGION="${AWS_REGION:-sa-east-1}"
TAG_NAME="${1:-netvision-k3s}"

log() { printf '\033[36m[verify]\033[0m %s\n' "$*"; }

INSTANCE_ID=$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Name,Values=${TAG_NAME}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' --output text | awk '{print $1}')

if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
  echo "FAIL: nenhuma instância Running com tag Name=${TAG_NAME}" >&2
  exit 1
fi
log "instância: $INSTANCE_ID"

run_on_node() {
  aws ssm send-command --region "$REGION" \
    --instance-id "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"$1\"]" \
    --query 'Command.CommandId' --output text
}

CMD_ID=$(run_on_node "k3s kubectl get nodes -o wide --no-headers")
sleep 6
NODES=$(aws ssm get-command-invocation --region "$REGION" \
  --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" \
  --query 'StandardOutputContent' --output text 2>/dev/null || true)

if ! echo "$NODES" | grep -q " Ready"; then
  echo "FAIL: nó k3s não está Ready. Saída:" >&2
  echo "$NODES" >&2
  exit 1
fi
log "nós Ready:"
echo "$NODES"

# Monta kubeconfig local: pega k3s.yaml via SSM e troca o endpoint pelo IP público.
PUBLIC_IP=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

CMD_ID=$(run_on_node "cat /etc/rancher/k3s/k3s.yaml")
sleep 5
K3S_YAML=$(aws ssm get-command-invocation --region "$REGION" \
  --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" \
  --query 'StandardOutputContent' --output text)

echo "$K3S_YAML" | sed "s#127.0.0.1:6443#${PUBLIC_IP}:6443#" > "${KUBECONFIG_OUT:-./kubeconfig}"
chmod 600 "${KUBECONFIG_OUT:-./kubeconfig}"
log "kubeconfig escrito em ${KUBECONFIG_OUT:-./kubeconfig} (server=https://${PUBLIC_IP}:6443)"

KUBECONFIG="${KUBECONFIG_OUT:-./kubeconfig}" kubectl get nodes
log "PASS: cluster k3s Ready"
