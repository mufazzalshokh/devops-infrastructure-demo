# Makefile — shortcuts for every common task
# Usage: make <target>
.PHONY: help build up down logs test lint shell k8s-deploy k8s-delete minikube-start

## Show this help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

## Build Docker image
build:
	docker compose build

## Start all services
up:
	docker compose up --build -d

## Stop all services
down:
	docker compose down

## Follow logs
logs:
	docker compose logs -f api

## Run tests
test:
	docker compose run --rm api pytest tests/ -v

## Lint + type check
lint:
	docker compose run --rm api sh -c "pip install ruff mypy -q && ruff check . && mypy app/"

## Open shell in running container
shell:
	docker compose exec api /bin/bash

## Start minikube cluster
minikube-start:
	minikube start --driver=docker
	minikube addons enable ingress
	minikube addons enable metrics-server

## Deploy to local Kubernetes
k8s-deploy:
	kubectl apply -f k8s/

## Delete K8s resources
k8s-delete:
	kubectl delete -f k8s/

## Show K8s pod status
k8s-status:
	kubectl get pods,services,ingress -n devops-demo

## Point Docker to minikube's daemon (run: eval $(make minikube-docker-env))
minikube-docker-env:
	minikube docker-env