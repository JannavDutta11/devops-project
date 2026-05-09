param(
    [Parameter(Mandatory=$true)]
    [string]$AcrName,
    
    [Parameter(Mandatory=$true)]
    [string]$AcrResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$AksClusterName,
    
    [Parameter(Mandatory=$true)]
    [string]$AksResourceGroup,
    
    [string]$ImageName = "devops-app",
    [string]$ImageTag = "latest"
)

$ErrorActionPreference = "Stop"

Write-Host "========== ACR & AKS Deployment Script ==========" -ForegroundColor Cyan

# Step 1: Enable ACR Admin
Write-Host "`n[1/10] Enabling ACR admin account..." -ForegroundColor Yellow
az acr update -n $AcrName --admin-enabled true

# Step 2: Get ACR credentials
Write-Host "`n[2/10] Retrieving ACR credentials..." -ForegroundColor Yellow
$AcrUrl = "$AcrName.azurecr.io"
$Username = az acr credential show -n $AcrName --query username -o tsv
$Password = az acr credential show -n $AcrName --query "passwords[0].value" -o tsv

Write-Host "ACR URL: $AcrUrl" -ForegroundColor Green
Write-Host "Username: $Username" -ForegroundColor Green

# Step 3: Build Docker image
Write-Host "`n[3/10] Building Docker image..." -ForegroundColor Yellow
docker build -t "${ImageName}:${ImageTag}" .
if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }

# Step 4: Tag image for ACR
Write-Host "`n[4/10] Tagging image for ACR..." -ForegroundColor Yellow
docker tag "${ImageName}:${ImageTag}" "${AcrUrl}/${ImageName}:${ImageTag}"

# Step 5: Log in to ACR
Write-Host "`n[5/10] Logging in to ACR..." -ForegroundColor Yellow
echo $Password | docker login -u $Username --password-stdin $AcrUrl
if ($LASTEXITCODE -ne 0) { throw "Docker login failed" }

# Step 6: Push image to ACR
Write-Host "`n[6/10] Pushing image to ACR..." -ForegroundColor Yellow
docker push "${AcrUrl}/${ImageName}:${ImageTag}"
if ($LASTEXITCODE -ne 0) { throw "Docker push failed" }

Write-Host "Image pushed successfully!" -ForegroundColor Green

# Step 7: Get AKS credentials
Write-Host "`n[7/10] Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials --resource-group $AksResourceGroup --name $AksClusterName --overwrite-existing
if ($LASTEXITCODE -ne 0) { throw "Failed to get AKS credentials" }

# Step 8: Create Kubernetes secret
Write-Host "`n[8/10] Creating Kubernetes secret for ACR..." -ForegroundColor Yellow
kubectl delete secret acr-secret --ignore-not-found
kubectl create secret docker-registry acr-secret `
  --docker-server=$AcrUrl `
  --docker-username=$Username `
  --docker-password=$Password `
  --docker-email=user@example.com
if ($LASTEXITCODE -ne 0) { throw "Failed to create Kubernetes secret" }

# Step 9: Update deployment.yaml
Write-Host "`n[9/10] Updating deployment manifest..." -ForegroundColor Yellow
$DeploymentFile = "kubernetes\deployment.yaml"
(Get-Content $DeploymentFile) -replace '<YOUR_ACR_NAME>', $AcrName | Set-Content $DeploymentFile
Write-Host "Updated $DeploymentFile" -ForegroundColor Green

# Step 10: Deploy to AKS
Write-Host "`n[10/10] Deploying to AKS..." -ForegroundColor Yellow
kubectl apply -f kubernetes\deployment.yaml
kubectl apply -f kubernetes\service.yaml

Write-Host "`n========== Deployment Complete ==========" -ForegroundColor Cyan
Write-Host "`nWaiting for service to get external IP..." -ForegroundColor Yellow

# Wait for external IP
$maxWait = 60
$waited = 0
while ($waited -lt $maxWait) {
    $service = kubectl get svc devops-app-service -o json | ConvertFrom-Json
    if ($service.status.loadBalancer.ingress.count -gt 0) {
        $externalIp = $service.status.loadBalancer.ingress[0].ip
        Write-Host "`n✓ Service External IP: $externalIp" -ForegroundColor Green
        Write-Host "`nAccess your app at:" -ForegroundColor Cyan
        Write-Host "  - http://$externalIp" -ForegroundColor Green
        Write-Host "  - http://$externalIp/health" -ForegroundColor Green
        Write-Host "  - http://$externalIp/info" -ForegroundColor Green
        Write-Host "  - http://$externalIp/docs" -ForegroundColor Green
        break
    }
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 2
    $waited += 2
}

Write-Host "`n`nDeployment Status:"
kubectl get pods
kubectl get svc
