# devops-infrastructure-demo

> Demonstrates production-grade deployment practices for Python microservices:
> Kubernetes, Terraform IaC, GitHub Actions CI/CD, and Prometheus monitoring.

![CI](https://github.com/mufazzalshokh/devops-infrastructure-demo/actions/workflows/ci.yml/badge.svg)
![CD](https://github.com/mufazzalshokh/devops-infrastructure-demo/actions/workflows/cd.yml/badge.svg)

## Architecture Overview
```
┌─────────────────────────────────────────────────────────┐
│                    GitHub Actions                        │
│  PR → CI (lint, test, build, validate) → merge → CD     │
└─────────────────────┬───────────────────────────────────┘
                      │ push image to GHCR
                      ▼
┌─────────────────────────────────────────────────────────┐
│              Kubernetes Cluster (minikube)               │
│                                                          │
│  Ingress (nginx) → Service → Deployment (2 replicas)    │
│                              └── HPA (2-10 pods)         │
│                                                          │
│  ConfigMap (env config)   Prometheus scrape /metrics     │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              Terraform (LocalStack)                      │
│                                                          │
│  VPC → Subnets → Security Group → EC2 → S3 → IAM        │
└─────────────────────────────────────────────────────────┘
```

## Stack

| Layer | Technology |
|---|---|
| Application | Python 3.12, FastAPI, Prometheus metrics |
| Container | Docker (non-root, single-stage) |
| Orchestration | Kubernetes — Deployment, Service, Ingress, HPA, ConfigMap |
| IaC | Terraform — VPC, EC2, S3, IAM on LocalStack |
| CI/CD | GitHub Actions — lint, test, build, push to GHCR, deploy |
| Monitoring | Prometheus + Grafana dashboard |

## Quick Start

### Run locally with Docker
```bash
docker compose up --build
curl http://localhost:8000/health
curl http://localhost:8000/docs   # Swagger UI
```

### Deploy to Kubernetes (minikube)
```bash
minikube start --driver=docker
minikube addons enable ingress
minikube addons enable metrics-server
minikube image load devops-infrastructure-demo-api:latest
kubectl apply -f k8s/
kubectl get all -n devops-demo
```

### Run Terraform (LocalStack)
```bash
# Start LocalStack first
docker run -d -p 4566:4566 localstack/localstack

cd terraform
terraform init
terraform plan
terraform apply
```

### Run monitoring stack
```bash
docker compose -f docker-compose.yml \
  -f monitoring/docker-compose.monitoring.yml up -d

# Prometheus: http://localhost:9090
# Grafana:    http://localhost:3000 (admin/admin)
```

## Project Structure
```
devops-infrastructure-demo/
├── app/                          # FastAPI application
│   ├── api/routes.py             # Endpoints: /health, /ready, /metrics, /search
│   ├── core/config.py            # Pydantic-settings configuration
│   ├── models/schemas.py         # Request/response schemas
│   ├── tests/test_api.py         # pytest test suite (7 tests)
│   ├── main.py                   # App factory, middleware, instrumentation
│   ├── requirements.txt
│   └── Dockerfile
├── k8s/                          # Kubernetes manifests
│   ├── namespace.yaml            # Isolated namespace
│   ├── configmap.yaml            # Non-sensitive configuration
│   ├── deployment.yaml           # 2 replicas, rolling update, probes
│   ├── service.yaml              # ClusterIP service
│   ├── ingress.yaml              # nginx ingress
│   └── hpa.yaml                  # Autoscale 2-10 pods on CPU/memory
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                   # VPC, subnets, EC2, S3, IAM
│   ├── variables.tf              # Parameterised with validation
│   ├── outputs.tf                # Exposed values
│   └── providers.tf              # AWS provider + LocalStack endpoints
├── monitoring/
│   ├── prometheus.yml            # Scrape config
│   ├── grafana-dashboard.json    # Request rate, latency p50/p95/p99, errors
│   └── docker-compose.monitoring.yml
├── .github/workflows/
│   ├── ci.yml                    # PR: lint, test, docker build, tf validate
│   └── cd.yml                    # Main: build, push GHCR, deploy
├── docker-compose.yml
├── Makefile
└── .env.example
```

## CI/CD Pipeline
```
Pull Request:                    Merge to main:
┌──────────┐                     ┌──────────────┐
│ ruff     │                     │ docker build │
│ pytest   │                     │ push → GHCR  │
│ docker   │────── green ──────► │ k8s deploy   │
│ tf plan  │                     └──────────────┘
│ kubeval  │
└──────────┘
```

## Key Design Decisions

**Why non-root Docker user?** Security best practice — if a container is compromised, the attacker doesn't get root on the host.

**Why HPA with both CPU and memory metrics?** Python apps can leak memory without spiking CPU. Monitoring both prevents OOM kills under sustained load.

**Why LocalStack instead of real AWS?** Zero cost, zero account needed, identical API surface. Documents that this is a demo environment.

**Why rolling update strategy with maxUnavailable=0?** Guarantees zero-downtime deploys — new pods must be healthy before old ones are removed.

## Demo Environment Note

This project uses minikube (local K8s) and LocalStack (simulated AWS) to demonstrate production-grade patterns without cloud costs. The same manifests and Terraform code deploy to real EKS/AWS by removing LocalStack endpoints and providing real credentials.