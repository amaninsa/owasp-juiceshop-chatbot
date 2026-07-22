# Juice Shop AI — local KIND / Docker orchestration
# Usage: make help

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export CLUSTER_NAME ?= juiceshop-chatbot
export NAMESPACE ?= juiceshop-chatbot
export PATH := /opt/homebrew/bin:$(PATH)

.DEFAULT_GOAL := help

.PHONY: help doctor clean demo urls kind-up deploy delete delete-all logs logs-backend logs-frontend logs-chromadb port-forward status build-images load-images helm-lint helm-template helm-install helm-uninstall kustomize-local kustomize-dev kustomize-prod argocd-install argocd-apply argocd-apps argocd-password argocd-ui argocd-status ci-lint ci-test validate monitoring monitoring-local monitoring-production monitoring-delete monitoring-status monitoring-port-forward

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n" } /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf "\nExamples:\n  make doctor\n  make kind-up && make deploy\n  make monitoring\n  make demo && make urls\n  make argocd-install && make argocd-apply\n  make clean\n\n"

doctor: ## Validate Docker/KIND/kubectl/disk/memory/ingress/monitoring/ArgoCD
	@chmod +x $(ROOT_DIR)/scripts/doctor.sh
	@$(ROOT_DIR)/scripts/doctor.sh

urls: ## Print AI / Grafana / Prometheus / Alertmanager / Argo CD / GitHub URLs
	@chmod +x $(ROOT_DIR)/scripts/urls.sh
	@$(ROOT_DIR)/scripts/urls.sh

demo: ## Run interview demo helper (cluster dump + URLs)
	@chmod +x $(ROOT_DIR)/scripts/demo.sh
	@$(ROOT_DIR)/scripts/demo.sh

clean: ## Safely reclaim local Docker/KIND disk (keeps cluster unless CLEAN_CLUSTER=true)
	@chmod +x $(ROOT_DIR)/scripts/clean.sh
	@$(ROOT_DIR)/scripts/clean.sh

kind-up: ## Create KIND cluster + install ingress-nginx
	@chmod +x $(ROOT_DIR)/scripts/*.sh
	@$(ROOT_DIR)/scripts/kind-up.sh

build-images: ## Build chromadb, backend, and frontend images
	@docker compose -f $(ROOT_DIR)/docker-compose.yml build chromadb backend frontend
	@docker image inspect owasp-juiceshop-chatbot-frontend:local >/dev/null 2>&1 || true

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

argocd-install: ## Install Argo CD (CRDs + server) and expose UI
	@chmod +x $(ROOT_DIR)/scripts/argocd-install.sh
	@$(ROOT_DIR)/scripts/argocd-install.sh

argocd-apply: ## Apply AppProject + App-of-Apps (requires make argocd-install)
	@chmod +x $(ROOT_DIR)/scripts/argocd-apply.sh
	@$(ROOT_DIR)/scripts/argocd-apply.sh

argocd-apps: ## Render child Applications (argocd/apps)
	@kubectl kustomize $(ROOT_DIR)/argocd/apps

argocd-password: ## Print Argo CD initial admin password
	@kubectl --context kind-$(CLUSTER_NAME) -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath='{.data.password}' | base64 --decode; echo

argocd-ui: ## Port-forward Argo CD UI to localhost:8081
	@printf 'Argo CD UI → http://127.0.0.1:8081  (admin / $$(make argocd-password))\n'
	@kubectl --context kind-$(CLUSTER_NAME) -n argocd port-forward svc/argocd-server 8081:80

argocd-status: ## Show Argo CD Applications and pods
	@kubectl --context kind-$(CLUSTER_NAME) -n argocd get applications,appprojects 2>/dev/null || \
		printf 'Argo CD CRDs missing — run: make argocd-install\n'
	@kubectl --context kind-$(CLUSTER_NAME) -n argocd get pods,svc,ingress 2>/dev/null || true

ci-lint: ## Run AI assistant format/lint/type checks (CI parity)
	@cd $(ROOT_DIR)/backend; \
		if [[ -x .venv/bin/black ]]; then export PATH="$(pwd)/.venv/bin:$$PATH"; fi; \
		black --check .; \
		isort --check-only .; \
		ruff check .; \
		ruff format --check .; \
		mypy .

ci-test: ## Run AI assistant pytest suite (CI parity)
	@cd $(ROOT_DIR)/backend; \
		if [[ -x .venv/bin/pytest ]]; then P=.venv/bin/pytest; else P=pytest; fi; \
		OPEN_AI_KEY=$${OPEN_AI_KEY:-test-key} \
		PRODUCTS_CONFIG_PATH=$(ROOT_DIR)/config/default.yml \
		$$P --cov=. --cov-report=term-missing

monitoring: ## Deploy observability stack (local profile: emptyDir + 24h retention)
	@chmod +x $(ROOT_DIR)/scripts/monitoring.sh
	@MONITORING_PROFILE=local $(ROOT_DIR)/scripts/monitoring.sh deploy

monitoring-local: ## Deploy local/KIND observability profile
	@$(MAKE) monitoring

monitoring-production: ## Deploy production-style profile (PVC + longer retention)
	@chmod +x $(ROOT_DIR)/scripts/monitoring.sh
	@MONITORING_PROFILE=production $(ROOT_DIR)/scripts/monitoring.sh deploy

monitoring-delete: ## Delete monitoring stack
	@chmod +x $(ROOT_DIR)/scripts/monitoring.sh
	@MONITORING_PROFILE=$${MONITORING_PROFILE:-local} $(ROOT_DIR)/scripts/monitoring.sh delete

monitoring-status: ## Show monitoring pods/services/ingress
	@chmod +x $(ROOT_DIR)/scripts/monitoring.sh
	@$(ROOT_DIR)/scripts/monitoring.sh status

monitoring-port-forward: ## Port-forward Grafana/Prometheus/Alertmanager/Loki
	@chmod +x $(ROOT_DIR)/scripts/monitoring.sh
	@$(ROOT_DIR)/scripts/monitoring.sh port-forward
