param(
    [string]$AcrName = "mydevopsacr",
    [string]$AcrResourceGroup = "devops-rg",
    [string]$AksClusterName = "devops-aks-cluster",
    [string]$AksResourceGroup = "devops-rg"
)

$ErrorActionPreference = "Stop"

Write-Host "========== Deploy to AKS ==========" -ForegroundColor Cyan

# Step 1: Get AKS credentials
Write-Host "`n[1/6] Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials --resource-group $AksResourceGroup --name $AksClusterName --overwrite-existing

# Step 2: Get ACR credentials
Write-Host "`n[2/6] Getting ACR credentials..." -ForegroundColor Yellow
$ACR_URL = "$AcrName.azurecr.io"
$USERNAME = az acr credential show -n $AcrName --query username -o tsv
$PASSWORD = az acr credential show -n $AcrName --query "passwords[0].value" -o tsv

Write-Host "ACR: $ACR_URL" -ForegroundColor Green

# Step 3: Build Docker image
Write-Host "`n[3/6] Building Docker image..." -ForegroundColor Yellow
docker build -t devops-app:latest .
if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }

# Step 4: Tag and push to ACR
Write-Host "`n[4/6] Pushing image to ACR..." -ForegroundColor Yellow
docker tag devops-app:latest $ACR_URL/devops-app:latest
echo $PASSWORD | docker login -u $USERNAME --password-stdin $ACR_URL
docker push $ACR_URL/devops-app:latest
if ($LASTEXITCODE -ne 0) { throw "Docker push failed" }

Write-Host "✓ Image pushed successfully!" -ForegroundColor Green

# Step 5: Create Kubernetes secret
Write-Host "`n[5/6] Creating Kubernetes secret..." -ForegroundColor Yellow
kubectl delete secret acr-secret --ignore-not-found
kubectl create secret docker-registry acr-secret `
  --docker-server=$ACR_URL `
  --docker-username=$USERNAME `
  --docker-password=$PASSWORD `
  --docker-email=user@example.com

# Step 6: Update and deploy manifests
Write-Host "`n[6/6] Deploying to AKS..." -ForegroundColor Yellow
(Get-Content kubernetes\deployment.yaml) -replace '<YOUR_ACR_NAME>', $AcrName | Set-Content kubernetes\deployment.yaml
kubectl apply -f kubernetes\deployment.yaml
kubectl apply -f kubernetes\service.yaml

Write-Host "`n========== Deployment Submitted ==========" -ForegroundColor Cyan
Write-Host "`nWaiting for service to get external IP..." -ForegroundColor Yellow

# Wait for external IP
$maxWait = 120
$waited = 0
while ($waited -lt $maxWait) {
    $serviceJson = kubectl get svc devops-app-service -o json 2>$null
    if ($serviceJson) {
        $service = $serviceJson | ConvertFrom-Json
        if ($service.status.loadBalancer.ingress -and $service.status.loadBalancer.ingress.Count -gt 0) {
            $externalIp = $service.status.loadBalancer.ingress[0].ip
            Write-Host "`n✓ External IP Assigned: $externalIp" -ForegroundColor Green
            Write-Host "`nAccess your app:" -ForegroundColor Cyan
            Write-Host "  - http://$externalIp/" -ForegroundColor Green
            Write-Host "  - http://$externalIp/health" -ForegroundColor Green
            Write-Host "  - http://$externalIp/info" -ForegroundColor Green
            Write-Host "  - http://$externalIp/docs (Swagger UI)" -ForegroundColor Green
            break
        }
    }
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 2
    $waited += 2
}

if ($waited -ge $maxWait) {
    Write-Host "`n⏳ Timeout waiting for external IP (cluster may still be initializing)" -ForegroundColor Yellow
    Write-Host "Check status with: kubectl get svc devops-app-service" -ForegroundColor Cyan
}

Write-Host "`n`nDeployment Status:" -ForegroundColor Cyan
kubectl get pods
kubectl get svc
