#!/usr/bin/env bash
# user_data — k3s server em EC2 spot (AL2023 arm64)
set -euo pipefail
exec > >(tee /var/log/k3s-userdata.log) 2>&1

echo "[netvision] iniciando instalacao do k3s em $(date -u)"

# Só saída HTTPS é necessária (SSM + registries) — SG já permite egress total.
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.31.3+k3s1" sh -s - server \
  --node-name="$(hostname)" \
  --write-kubeconfig-mode=644 \
  --disable=traefik \
  --tls-san="$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 || echo 127.0.0.1)"

# Espera a API local ficar de pé antes de declarar sucesso
for i in $(seq 1 30); do
  if k3s kubectl get --raw=/readyz >/dev/null 2>&1; then
    echo "[netvision] k3s READY em $(date -u)"
    k3s kubectl get nodes -o wide
    exit 0
  fi
  sleep 5
done

echo "[netvision] ERRO: API do k3s nao respondeu em 150s" >&2
exit 1
