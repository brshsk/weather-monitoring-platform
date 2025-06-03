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
  description = "Application name"
  type        = string
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.app_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30  # Cost optimization - minimum retention

  tags = {
    Environment = var.environment
    Component   = "monitoring"
    ManagedBy   = "OpenTofu"
  }
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.app_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "java"
  
  # Cost optimization settings
  sampling_percentage = 10  # Sample only 10% of telemetry
  
  tags = {
    Environment = var.environment
    Component   = "monitoring"
    ManagedBy   = "OpenTofu"
  }
}

# Outputs
output "instrumentation_key" {
  value = azurerm_application_insights.main.instrumentation_key
  sensitive = true
}

output "connection_string" {
  value = azurerm_application_insights.main.connection_string
  sensitive = true
}

output "app_id" {
  value = azurerm_application_insights.main.app_id
}