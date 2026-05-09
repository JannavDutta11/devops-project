provider "azurerm" {
  features {}
}
 
resource "azurerm_resource_group" "rg" {
  name     = "devops-rg"
  location = "southindia"
}
 
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "devops-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "devopsaks"
 
  default_node_pool {
    name       = "nodepool"
    node_count = 1
    vm_size    = "Standard_B2s_v2"
  }
 
  identity {
    type = "SystemAssigned"
  }
}
 