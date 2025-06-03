terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "app_name" {
  description = "Name of the web application"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault ID for storing secrets"
  type        = string
}

variable "application_insights_key" {
  description = "Application Insights instrumentation key"
  type        = string
}

# App Service Plan (B1 Basic - cost optimized)
resource "azurerm_service_plan" "main" {
  name                = "asp-${var.app_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "B1"  # Basic tier - cost optimized

  tags = {
    Environment = var.environment
    Component   = "app-service"
    ManagedBy   = "OpenTofu"
  }
}

# App Service
resource "azurerm_linux_web_app" "main" {
  name                = "app-${var.app_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    always_on = false  # Cost optimization - allows app to sleep
    
    application_stack {
      java_server         = "JAVA"
      java_server_version = "17"
      java_version        = "17"
    }

    # Health check configuration
    health_check_path                 = "/actuator/health"
    health_check_eviction_time_in_min = 2
  }

  # App settings
  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "APPINSIGHTS_INSTRUMENTATIONKEY"      = var.application_insights_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = "InstrumentationKey=${var.application_insights_key}"
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
    "SPRING_PROFILES_ACTIVE"              = var.environment
  }

  # Identity for Key Vault access
  identity {
    type = "SystemAssigned"
  }

  # Deployment slot for staging
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }

  tags = {
    Environment = var.environment
    Component   = "web-app"
    ManagedBy   = "OpenTofu"
  }
}

# Staging slot
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id

  site_config {
    always_on = false
    
    application_stack {
      java_server         = "JAVA"
      java_server_version = "17"
      java_version        = "17"
    }

    health_check_path = "/actuator/health"
  }

  app_settings = azurerm_linux_web_app.main.app_settings

  tags = {
    Environment = "${var.environment}-staging"
    Component   = "web-app-staging"
    ManagedBy   = "OpenTofu"
  }
}

# Key Vault access policy for App Service
resource "azurerm_key_vault_access_policy" "app_service" {
  key_vault_id = var.key_vault_id
  tenant_id    = azurerm_linux_web_app.main.identity[0].tenant_id
  object_id    = azurerm_linux_web_app.main.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Outputs
output "app_service_name" {
  value = azurerm_linux_web_app.main.name
}

output "app_service_default_hostname" {
  value = azurerm_linux_web_app.main.default_hostname
}

output "app_service_id" {
  value = azurerm_linux_web_app.main.id
}

output "staging_hostname" {
  value = azurerm_linux_web_app_slot.staging.default_hostname
}