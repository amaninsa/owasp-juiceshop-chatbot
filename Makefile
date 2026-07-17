# Juice Shop AI — local KIND / Docker orchestration
# Usage: make help

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export CLUSTER_NAME ?= juiceshop-chatbot
export NAMESPACE ?= juiceshop-chatbot
export PATH := /opt/homebrew/bin:$(PATH)

.DEFAULT_GOAL := help

.PHONY: help kind-up deploy delete delete-all logs logs-backend logs-frontend logs-chromadb port-forward status build-images load-images helm-lint helm-template helm-install helm-uninstall kustomize-local kustomize-dev kustomize-prod argocd-apply ci-lint ci-test validate

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n" } /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf "\nExamples:\n  make kind-up\n  make deploy\n  make port-forward\n  make logs\n  make delete\n  make delete-all\n\n"

kind-up: ## Create KIND cluster + install ingress-nginx
	@chmod +x $(ROOT_DIR)/scripts/*.sh
	@$(ROOT_DIR)/scripts/kind-up.sh

build-images: ## Build chromadb, backend, and juice-shop images
	@docker compose -f $(ROOT_DIR)/docker-compose.yml build chromadb backend juice-shop
	@docker image inspect owasp-juiceshop-chatbot-frontend:local >/dev/null 2>&1 || docker tag juice-shop-juice-shop:latest owasp-juiceshop-chatbot-frontend:local

load-images: ## Load local images into KIND
	@kind load docker-image owasp-juiceshop-chatbot-chromadb:local --name $(CLUSTER_NAME)
	@kind load docker-image owasp-juiceshop-chatbot-backend:local --name $(CLUSTER_NAME)
	@kind load docker-image owasp-juiceshop-chatbot-frontend:local --name $(CLUSTER_NAME)

deploy: ## Build/load images (optional) and deploy manifests to KIND
	@chmod +x $(ROOT_DIR)/scripts/*.sh
	@$(ROOT_DIR)/scripts/deploy.sh

deploy-fast: ## Deploy without rebuilding images
	@chmod +x $(ROOT_DIR)/scripts/*.sh
	@BUILD_IMAGES=false $(ROOT_DIR)/scripts/deploy.sh

delete: ## Delete Kubernetes workloads (keeps KIND cluster)
	@chmod +x $(ROOT_DIR)/scripts/*.sh
	@$(ROOT_DIR)/scripts/delete.sh

delete-all: ## Delete workloads and destroy KIND cluster
	@chmod +x $(ROOT_DIR)/scripts/*.sh
	@DELETE_CLUSTER=true $(ROOT_DIR)/scripts/delete.sh

logs: ## Tail logs for all Juice Shop AI pods
	@chmod +x $(ROOT_DIR)/scripts/*.sh
	@$(ROOT_DIR)/scripts/logs.sh all

logs-backend: ## Tail backend logs
	@$(ROOT_DIR)/scripts/logs.sh backend

logs-frontend: ## Tail frontend logs
	@$(ROOT_DIR)/scripts/logs.sh frontend

logs-chromadb: ## Tail ChromaDB logs
	@$(ROOT_DIR)/scripts/logs.sh chromadb

port-forward: ## Port-forward frontend(:3000) and backend(:8000)
	@chmod +x $(ROOT_DIR)/scripts/*.sh
	@$(ROOT_DIR)/scripts/port-forward.sh

status: ## Show pods/services/ingress/events
	@chmod +x $(ROOT_DIR)/scripts/*.sh
	@$(ROOT_DIR)/scripts/status.sh

validate: ## Validate pods/services/ingress/health/Chroma/OpenAI
	@chmod +x $(ROOT_DIR)/scripts/validate.sh
	@$(ROOT_DIR)/scripts/validate.sh

helm-lint: ## Lint the Helm chart
	@helm lint $(ROOT_DIR)/helm -f $(ROOT_DIR)/helm/values-local.yaml

helm-template: ## Render Helm templates for local values
	@helm template juiceshop-chatbot $(ROOT_DIR)/helm -n juiceshop-chatbot -f $(ROOT_DIR)/helm/values-local.yaml

helm-install: ## Install/upgrade chart into KIND (uses values-local.yaml)
	@helm upgrade --install juiceshop-chatbot $(ROOT_DIR)/helm \
		--namespace juiceshop-chatbot --create-namespace \
		-f $(ROOT_DIR)/helm/values-local.yaml \
		--wait --timeout 10m

helm-uninstall: ## Uninstall Helm release
	@helm uninstall juiceshop-chatbot --namespace juiceshop-chatbot || true

kustomize-local: ## Render GitOps local overlay
	@kubectl kustomize $(ROOT_DIR)/apps/overlays/local

kustomize-dev: ## Render GitOps dev overlay
	@kubectl kustomize $(ROOT_DIR)/apps/overlays/dev

kustomize-prod: ## Render GitOps prod overlay
	@kubectl kustomize $(ROOT_DIR)/apps/overlays/prod

argocd-apply: ## Apply ArgoCD Project + Applications (requires argocd ns)
	@kubectl apply -k $(ROOT_DIR)/argocd

ci-lint: ## Run AI assistant ruff lint/format checks (CI parity)
	@cd $(ROOT_DIR)/backend; \
		if [[ -x .venv/bin/ruff ]]; then R=.venv/bin/ruff; else R=ruff; fi; \
		$$R check .; $$R format --check .

ci-test: ## Run AI assistant pytest suite (CI parity)
	@cd $(ROOT_DIR)/backend; \
		if [[ -x .venv/bin/pytest ]]; then P=.venv/bin/pytest; else P=pytest; fi; \
		OPEN_AI_KEY=$${OPEN_AI_KEY:-test-key} \
		PRODUCTS_CONFIG_PATH=$(ROOT_DIR)/config/default.yml \
		$$P --cov=. --cov-report=term-missing
