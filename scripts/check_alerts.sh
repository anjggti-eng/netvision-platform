#!/usr/bin/env bash
# Teste do Task 7: exatamente 2 PrometheusRules com severity + dashboards JSON válidos.
set -euo pipefail
cd "$(dirname "$0")/.."

RULES=$(find cluster/platform/monitoring/alerts -name '*.yaml' | wc -l)
[[ "$RULES" -eq 2 ]] || { echo "FAIL: esperado 2 arquivos de alerta, encontrado $RULES" >&2; exit 1; }

SEV=$(grep -h "severity:" cluster/platform/monitoring/alerts/*.yaml | wc -l)
[[ "$SEV" -ge 2 ]] || { echo "FAIL: menos de 2 regras com severity" >&2; exit 1; }

grep -q "for: 5m" cluster/platform/monitoring/alerts/node-high-cpu.yaml || { echo "FAIL: alerta de CPU sem janela 'for'" >&2; exit 1; }
grep -q "for: 2m" cluster/platform/monitoring/alerts/pod-down.yaml || { echo "FAIL: alerta de pod sem janela 'for'" >&2; exit 1; }

for f in cluster/platform/monitoring/dashboards/*.json; do
  python3 -c "import json,sys; d=json.load(open('$f')); assert d['panels'], 'sem painéis'" || exit 1
done

grep -q 'grafana_dashboard' cluster/platform/monitoring/kustomization.yaml || { echo "FAIL: ConfigMap de dashboards sem label grafana_dashboard" >&2; exit 1; }

echo "PASS: 2 alertas + dashboards válidos"
