# 🚀 Complete Deployment Guide - ACR to AKS

## Your Configuration
- **Subscription**: Visual Studio Professional Subscription (`ac2589a2-f1eb-48fd-a009-895cd9307895`)
- **Resource Group**: `devops-rg` (exists in `southindia`)
- **ACR**: `mydevopsacr.azurecr.io`
- **AKS Cluster**: `devops-aks-cluster`
- **Region**: `southindia`

---

## ⏳ WAIT: Provider Registration in Progress

**Status**: Registering `Microsoft.ContainerService`

This can take 5-15 minutes. Check status:
```powershell
az provider show -n Microsoft.ContainerService --query "registrationState" -o tsv
```

**Expected output when ready**: `Registered`

---

## Once Registration is Complete: Option A - Automated Deployment

```powershell
cd c:\Users\RD284VK\devops-project

# Create AKS cluster (if not already created)
az aks create --resource-group devops-rg `
  --name devops-aks-cluster `
  --node-count 1 `
  --vm-set-type VirtualMachineScaleSets `
  --load-balancer-sku standard `
  --enable-managed-identity `
  --network-plugin azure `
  --node-vm-size Standard_B2s

# Get AKS credentials
az aks get-credentials --resource-group devops-rg --name devops-aks-cluster --overwrite-existing

# Run deployment
.\deploy.ps1 -AcrName mydevopsacr -AcrResourceGroup devops-rg -AksClusterName devops-aks-cluster -AksResourceGroup devops-rg
```

---

## Option B - Manual Step-by-Step

### 1. Create AKS Cluster (10-15 minutes)
```powershell
az aks create --resource-group devops-rg `
  --name devops-aks-cluster `
  --node-count 1 `
  --vm-set-type VirtualMachineScaleSets `
  --load-balancer-sku standard `
  --enable-managed-identity `
  --network-plugin azure `
  --node-vm-size Standard_B2s `
  --yes
```

### 2. Get AKS Credentials
```powershell
az aks get-credentials --resource-group devops-rg --name devops-aks-cluster --overwrite-existing
```

### 3. Verify Cluster
```powershell
kubectl get nodes
```

### 4. Verify ACR Exists
```powershell
az acr list --resource-group devops-rg
```

If not created yet:
```powershell
az acr create --resource-group devops-rg --name mydevopsacr --sku Basic --admin-enabled true
```

### 5. Build and Push Docker Image
```powershell
cd c:\Users\RD284VK\devops-project

# Get ACR login credentials
$USERNAME = az acr credential show -n mydevopsacr --query username -o tsv
$PASSWORD = az acr credential show -n mydevopsacr --query "passwords[0].value" -o tsv
$ACR_URL = "mydevopsacr.azurecr.io"

# Build image
docker build -t devops-app:latest .

# Tag for ACR
docker tag devops-app:latest $ACR_URL/devops-app:latest

# Login to ACR
echo $PASSWORD | docker login -u $USERNAME --password-stdin $ACR_URL

# Push image
docker push $ACR_URL/devops-app:latest
```

### 6. Create Kubernetes Secret
```powershell
kubectl create secret docker-registry acr-secret `
  --docker-server=$ACR_URL `
  --docker-username=$USERNAME `
  --docker-password=$PASSWORD `
  --docker-email=user@example.com
```

### 7. Update Deployment
```powershell
# Update deployment.yaml with ACR name
(Get-Content kubernetes\deployment.yaml) -replace '<YOUR_ACR_NAME>', 'mydevopsacr' | Set-Content kubernetes\deployment.yaml
```

### 8. Deploy to AKS
```powershell
kubectl apply -f kubernetes\deployment.yaml
kubectl apply -f kubernetes\service.yaml
```

### 9. Check Deployment
```powershell
kubectl get pods
kubectl get svc devops-app-service
```

### 10. Get External IP and Access App
```powershell
# Watch for external IP (may take 2-3 minutes)
kubectl get svc devops-app-service --watch
```

Once you see an EXTERNAL-IP:
```
http://<EXTERNAL-IP>/
http://<EXTERNAL-IP>/health
http://<EXTERNAL-IP>/info
http://<EXTERNAL-IP>/docs
```

---

## 🆘 Troubleshooting

### Check Provider Status
```powershell
az provider show -n Microsoft.ContainerService
az provider show -n Microsoft.Compute
az provider show -n Microsoft.Network
```

### Check AKS Status
```powershell
az aks show -g devops-rg -n devops-aks-cluster --query powerState
az aks show -g devops-rg -n devops-aks-cluster --query provisioningState
```

### View Pod Logs
```powershell
kubectl logs <pod-name>
kubectl describe pod <pod-name>
```

### Check ImagePullBackOff
```powershell
kubectl describe pod <pod-name>
kubectl get secrets
```

### Restart Deployment
```powershell
kubectl rollout restart deployment/devops-app
```

---

## ✅ Summary of Files Ready to Deploy

- ✓ **Dockerfile** - Docker image definition
- ✓ **.dockerignore** - Build optimization
- ✓ **kubernetes/deployment.yaml** - K8s deployment (ready to use)
- ✓ **kubernetes/service.yaml** - LoadBalancer service
- ✓ **deploy.ps1** - Automated deployment script
- ✓ **app/app.py** - FastAPI application with health checks

Ready to go! Just wait for provider registration to complete.
