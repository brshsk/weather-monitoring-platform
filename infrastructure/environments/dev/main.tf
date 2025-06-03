terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
  use_oidc = true
}

# Local variables
locals {
  environment = "dev"
  location    = "Sweden Central"
  project     = "weather-monitoring"
}

# Resource Group
module "resource_group" {
  source = "../../modules/resource-group"
  
  resource_group_name = "rg-${local.project}-${local.environment}"
  location           = local.location
  environment        = local.environment
  project_name       = local.project
}

# Key Vault
module "key_vault" {
  source = "../../modules/key-vault"
  
  resource_group_name = module.resource_group.resource_group_name
  location           = local.location
  environment        = local.environment
  key_vault_name     = local.project
  
  depends_on = [module.resource_group]
}

# Application Insights
module "monitoring" {
  source = "../../modules/monitoring"
  
  resource_group_name = module.resource_group.resource_group_name
  location           = local.location
  environment        = local.environment
  app_name           = local.project
  
  depends_on = [module.resource_group]
}

# Database
module "database" {
  source = "../../modules/database"
  
  resource_group_name = module.resource_group.resource_group_name
  location           = local.location
  environment        = local.environment
  server_name        = local.project
  admin_password     = ""  # Will generate random password
  key_vault_id       = module.key_vault.key_vault_id
  
  depends_on = [module.key_vault]
}

# App Service
module "app_service" {
  source = "../../modules/app-service"
  
  resource_group_name        = module.resource_group.resource_group_name
  location                  = local.location
  environment               = local.environment
  app_name                  = local.project
  key_vault_id              = module.key_vault.key_vault_id
  application_insights_key  = module.monitoring.instrumentation_key
  
  depends_on = [module.key_vault, module.monitoring]
}

# Store weather API key placeholder in Key Vault
resource "azurerm_key_vault_secret" "weather_api_key" {
  name         = "weather-api-key"
  value        = "your-openweathermap-api-key-here"
  key_vault_id = module.key_vault.key_vault_id

  tags = {
    Environment = local.environment
    Component   = "configuration"
  }
}

# Outputs
output "resource_group_name" {
  value = module.resource_group.resource_group_name
}

output "app_service_url" {
  value = "https://${module.app_service.app_service_default_hostname}"
}

output "staging_url" {
  value = "https://${module.app_service.staging_hostname}"
}

output "database_host" {
  value = module.database.server_fqdn
}

output "key_vault_name" {
  value = module.key_vault.key_vault_name
}