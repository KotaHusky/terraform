provider "azurerm" {
  features {}
}

# Include other .tf files
module "aks" {
  source = "./aks-shared"
}

module "acr" {
  source = "./acr-shared"
}