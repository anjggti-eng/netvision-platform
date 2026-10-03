#!/usr/bin/env bash
# Bootstrap do GitOps: ArgoCD (Helm, pinned) + app raiz (app-of-apps).
# Pré-requisito: kubeconfig válido (gerado por scripts/verify_cluster.sh).
set -euo pipefail

ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.9.6}"
RELEASE="${RELEASE:-argocd}"
NAMESPACE="${NAMESPACE:-argocd}"

log() { printf '\033[36m[gitops]\033[0m %s\n' "$*"; }

command -v helm >/dev/null || { echo "FAIL: helm não instalado" >&2; exit 1; }
command -v kubectl >/dev/null || { echo "FAIL: kubectl não instalado" >&2; exit 1; }

log "instalando ArgoCD ${ARGOCD_CHART_VERSION}..."
helm repo add argo https://argoproj.github.io/argo-helm --force-update >/dev/null
helm upgrade --install "$RELEASE" argo/argo-cd \
  --namespace "$NAMESPACE" --create-namespace \
  --version "$ARGOCD_CHART_VERSION" \
  --wait --timeout 5m

log "aplicando app raiz (app-of-apps)..."
kubectl apply -k cluster/gitops

log "aguardando CRDs do ArgoCD..."
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=60s

log "aguardando controlador..."
kubectl -n "$NAMESPACE" rollout status deploy/argocd-server --timeout=300s || true

log "aplicações registradas:"
kubectl get applications -n "$NAMESPACE" || true

log "PASS: gitops bootstrapped. Extraia a senha do admin com:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
