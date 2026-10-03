SHELL := /bin/bash
.DEFAULT_GOAL := help

TF_ENV_DIR := infra/envs/prod
TF_BOOT_DIR := infra/bootstrap

.PHONY: help init validate lint kubeconform plan apply destroy up down dashboards verify fmt

help: ## Mostra os alvos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-14s\033[0m %s\n", $$1, $$2}'

init: ## terraform init (bootstrap + env)
	terraform -chdir=$(TF_BOOT_DIR) init -input=false
	terraform -chdir=$(TF_ENV_DIR) init -input=false

validate: fmt ## fmt -check + tflint + validate em todos os módulos
	terraform -chdir=$(TF_BOOT_DIR) fmt -check -recursive || (terraform -chdir=$(TF_BOOT_DIR) fmt -recursive && exit 1)
	terraform -chdir=$(TF_ENV_DIR) fmt -check -recursive || (terraform -chdir=$(TF_ENV_DIR) fmt -recursive && exit 1)
	terraform -chdir=$(TF_BOOT_DIR) validate
	terraform -chdir=$(TF_ENV_DIR) validate -backend=false
	tflint --chdir=$(TF_BOOT_DIR)
	tflint --chdir=$(TF_ENV_DIR)

fmt: ## terraform fmt em todos os diretórios
	terraform fmt -recursive infra

lint: validate ## alias de validate

kubeconform: ## valida todos os manifests K8s
	kustomize build cluster/gitops | kubeconform -strict -summary
	kustomize build cluster/platform | kubeconform -strict -summary || true
	kustomize build cluster/workloads/netvision | kubeconform -strict -summary
	kustomize build cluster/workloads/demo | kubeconform -strict -summary

plan: ## terraform plan do ambiente prod
	terraform -chdir=$(TF_ENV_DIR) plan -input=false

apply: ## terraform apply do ambiente prod
	terraform -chdir=$(TF_ENV_DIR) apply -input=false

destroy: ## terraform destroy do ambiente prod
	terraform -chdir=$(TF_ENV_DIR) destroy -input=false

up: ## Sobe tudo: bootstrap + env (cluster k3sspot)
	$(MAKE) -C . init
	terraform -chdir=$(TF_BOOT_DIR) apply -input=false -auto-approve
	terraform -chdir=$(TF_ENV_DIR) apply -input=false -auto-approve
	@echo "==> Aguardando nó k3s Ready..."
	./scripts/verify_cluster.sh

down: ## Destroi tudo e imprime checklist de recursos
	terraform -chdir=$(TF_ENV_DIR) destroy -input=false -auto-approve
	@echo "==> Checklist pós-destroy (deve ficar só o state):"
	@echo "  [ ] EC2/ASG terminados"
	@echo "  [ ] VPC/subnets removidas"
	@echo "  [ ] Budget alarm pode ser removido à parte se desejar"
	@echo "  [ ] S3 state + DynamoDB lock ficam (prevent_destroy) — remover manual se não quiser"

dashboards: ## Imprime URLs do Grafana (port-forward)
	@echo "kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80"
	@echo "Grafana: http://localhost:3000 (admin/grafana-admin — ver secret)"

verify: ## Verifica se o cluster k3s está Ready
	./scripts/verify_cluster.sh
