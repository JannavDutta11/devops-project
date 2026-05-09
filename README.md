# DevOps Project - FastAPI on Azure AKS

A containerized FastAPI application deployed to Azure Kubernetes Service (AKS) with CI/CD via GitHub Actions.

## Architecture

- **App:** Python FastAPI with Uvicorn
- **Container:** Docker (Python 3.14-slim)
- **Registry:** Azure Container Registry (ACR)
- **Orchestration:** Azure Kubernetes Service (AKS)
- **CI/CD:** GitHub Actions
- **IaC:** Terraform

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | Home - App status |
| `/health` | Health check |
| `/info` | App info with hostname |
| `/docs` | Swagger API docs |

## Project Structure

```
├── app/
│   ├── app.py              # FastAPI application
│   └── requirements.txt    # Python dependencies
├── kubernetes/
│   ├── deployment.yaml     # K8s deployment (2 replicas)
│   └── service.yaml        # LoadBalancer service
├── terraform/
│   └── main.tf             # Infrastructure as Code
├── .github/workflows/
│   └── deploy.yml          # CI/CD pipeline
├── Dockerfile              # Container definition
└── .gitignore
```

## Quick Start

```bash
# Local run
pip install -r app/requirements.txt
uvicorn app.app:app --host 0.0.0.0 --port 8000

# Deploy to AKS
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
```