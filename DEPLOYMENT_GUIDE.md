# ACR & AKS Deployment Guide

## Prerequisites
- Azure CLI installed
- Docker installed
- kubectl installed

## Step 1: Set Environment Variables
```powershell
$ACR_NAME = "your-acr-name"  # e.g., "myacrregistry"
$ACR_RESOURCE_GROUP = "your-resource-group"
$AKS_RESOURCE_GROUP = "your-aks-resource-group"
$AKS_CLUSTER_NAME = "your-aks-cluster"
$IMAGE_NAME = "devops-app"
$IMAGE_TAG = "latest"
```

## Step 2: Log in to Azure
```powershell
az login
az account set --subscription "your-subscription-id"
```

## Step 3: Enable ACR Admin Account (for username/password auth)
```powershell
az acr update -n $ACR_NAME --admin-enabled true
```

## Step 4: Get ACR Credentials (username and password)
```powershell
$ACR_URL = "$ACR_NAME.azurecr.io"
$USERNAME = az acr credential show -n $ACR_NAME --query username -o tsv
$PASSWORD = az acr credential show -n $ACR_NAME --query "passwords[0].value" -o tsv

Write-Host "ACR URL: $ACR_URL"
Write-Host "Username: $USERNAME"
Write-Host "Password: $PASSWORD"
```

## Step 5: Build Docker Image
```powershell
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
```

## Step 6: Tag Image for ACR
```powershell
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ACR_URL}/${IMAGE_NAME}:${IMAGE_TAG}
```

## Step 7: Log in to ACR
```powershell
docker login -u $USERNAME -p $PASSWORD $ACR_URL
```

## Step 8: Push Image to ACR
```powershell
docker push ${ACR_URL}/${IMAGE_NAME}:${IMAGE_TAG}
```

## Step 9: Create Kubernetes Secret for ACR
```powershell
kubectl create secret docker-registry acr-secret `
  --docker-server=$ACR_URL `
  --docker-username=$USERNAME `
  --docker-password=$PASSWORD `
  --docker-email=user@example.com
```

## Step 10: Update deployment.yaml
Replace `<YOUR_ACR_NAME>` with your actual ACR name:
```powershell
(Get-Content kubernetes\deployment.yaml) -replace '<YOUR_ACR_NAME>', $ACR_NAME | Set-Content kubernetes\deployment.yaml
```

## Step 11: Deploy to AKS
```powershell
# Get AKS credentials
az aks get-credentials --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME

# Apply manifests
kubectl apply -f kubernetes\deployment.yaml
kubectl apply -f kubernetes\service.yaml
```

## Step 12: Verify Deployment
```powershell
# Check pods
kubectl get pods

# Check service and get external IP
kubectl get svc devops-app-service

# View deployment status
kubectl describe deployment devops-app
```

## Step 13: Access Your App
Once the LoadBalancer service gets an EXTERNAL-IP, access your app at:
```
http://<EXTERNAL-IP>
http://<EXTERNAL-IP>/health
http://<EXTERNAL-IP>/info
```

## Troubleshooting

### ImagePullBackOff error
If pods show ImagePullBackOff, verify:
1. Secret was created: `kubectl get secrets`
2. Image exists in ACR: `az acr repository list -n $ACR_NAME`
3. Image name/tag is correct in deployment.yaml

### Verify Secret
```powershell
kubectl get secret acr-secret -o yaml
```

### View Pod Logs
```powershell
kubectl logs <pod-name>
```

### Troubleshoot Pod Events
```powershell
kubectl describe pod <pod-name>
```
