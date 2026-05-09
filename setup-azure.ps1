param(
    [string]$SubscriptionId = "ac2589a2-f1eb-48fd-a009-895cd9307895",
    [string]$ResourceGroup = "devops-rg",
    [string]$Region = "eastus",
    [string]$AcrName = "mydevopsacr",
    [string]$AksClusterName = "devops-aks-cluster",
    [int]$AksNodeCount = 1,
    [string]$AksVmSize = "Standard_B2s"
)

$ErrorActionPreference = "Stop"

Write-Host "========== Azure ACR & AKS Setup ==========" -ForegroundColor Cyan
Write-Host "Subscription: $SubscriptionId" -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Green
Write-Host "Region: $Region" -ForegroundColor Green
Write-Host "ACR Name: $AcrName" -ForegroundColor Green
Write-Host "AKS Cluster: $AksClusterName" -ForegroundColor Green
Write-Host "Node Count: $AksNodeCount" -ForegroundColor Green

# Step 1: Set subscription
Write-Host "`n[1/5] Setting Azure subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription" }

# Step 2: Create resource group
Write-Host "`n[2/5] Creating resource group..." -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Region
Write-Host "✓ Resource group created/verified" -ForegroundColor Green

# Step 3: Create ACR
Write-Host "`n[3/5] Creating Azure Container Registry..." -ForegroundColor Yellow
az acr create --resource-group $ResourceGroup `
  --name $AcrName `
  --sku Basic `
  --admin-enabled true
Write-Host "✓ ACR created successfully" -ForegroundColor Green

# Step 4: Create AKS Cluster
Write-Host "`n[4/5] Creating AKS cluster (this may take 5-10 minutes)..." -ForegroundColor Yellow
az aks create --resource-group $ResourceGroup `
  --name $AksClusterName `
  --node-count $AksNodeCount `
  --vm-set-type VirtualMachineScaleSets `
  --load-balancer-sku standard `
  --enable-managed-identity `
  --network-plugin azure `
  --docker-bridge-address 172.17.0.1/16 `
  --vm-set-type VirtualMachineScaleSets `
  --node-vm-size $AksVmSize

if ($LASTEXITCODE -ne 0) { throw "AKS creation failed" }
Write-Host "✓ AKS cluster created successfully" -ForegroundColor Green

# Step 5: Attach ACR to AKS
Write-Host "`n[5/5] Attaching ACR to AKS..." -ForegroundColor Yellow
$AcrId = az acr show --resource-group $ResourceGroup --name $AcrName --query id --output tsv
az aks update --name $AksClusterName --resource-group $ResourceGroup --attach-acr $AcrId
if ($LASTEXITCODE -ne 0) { throw "Failed to attach ACR" }

Write-Host "`n========== Setup Complete ==========" -ForegroundColor Cyan
Write-Host "`n✓ ACR: $AcrName.azurecr.io" -ForegroundColor Green
Write-Host "✓ AKS: $AksClusterName in $ResourceGroup" -ForegroundColor Green

# Get credentials
Write-Host "`nGetting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials --resource-group $ResourceGroup --name $AksClusterName --overwrite-existing

Write-Host "`n========== Next Steps ==========" -ForegroundColor Cyan
Write-Host "1. Run the deployment script:" -ForegroundColor Yellow
Write-Host "   .\deploy.ps1 -AcrName $AcrName -AcrResourceGroup $ResourceGroup -AksClusterName $AksClusterName -AksResourceGroup $ResourceGroup" -ForegroundColor Green
Write-Host "`n2. Or manually run:" -ForegroundColor Yellow
Write-Host "   kubectl get nodes" -ForegroundColor Green
Write-Host "   kubectl get pods" -ForegroundColor Green

# Test kubectl connection
Write-Host "`nVerifying kubectl connection..." -ForegroundColor Yellow
kubectl get nodes
Write-Host "✓ kubectl is connected and working!" -ForegroundColor Green
