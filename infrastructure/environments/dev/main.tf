terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  
  # Configure remote state (we'll add this later)
  # backend "azurerm" {
  #   resource_group_name  = "rg-weather-tfstate"
  #   storage_account_name = "saweathertfstate"
  #   container_name       = "tfstate"
  #   key                  = "dev.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
  use_oidc = true
}

# Local variables
locals {
  environment = "dev"
  location    = "Sweden Central"
  project     = "weather-monitoring"
}

# Resource Group name
module "resource_group" {
  source = "../../modules/resource-group"
  
  resource_group_name = "rg-${local.project}-${local.environment}"
  location           = local.location
  environment        = local.environment
  project_name       = local.project
}

# Output values
output "resource_group_name" {
  value = module.resource_group.resource_group_name
}

output "resource_group_id" {
  value = module.resource_group.resource_group_id
}