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

variable "server_name" {
  description = "PostgreSQL server name"
  type        = string
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = "weatherdb"
}

variable "admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "weatheradmin"
}

variable "admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "key_vault_id" {
  description = "Key Vault ID for storing connection strings"
  type        = string
}

# Random password generation
resource "random_password" "db_password" {
  count   = var.admin_password == "" ? 1 : 0
  length  = 16
  special = true
}

locals {
  admin_password = var.admin_password != "" ? var.admin_password : random_password.db_password[0].result
}

# PostgreSQL Flexible Server (cost-optimized)
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "psql-${var.server_name}-${var.environment}"
  resource_group_name    = var.resource_group_name
  location              = var.location
  version               = "15"
  
  # Cost-optimized settings
  sku_name                     = "B_Standard_B1ms"  # Burstable, 1 vCore, 2GB RAM
  storage_mb                   = 32768              # 32GB storage (minimum)
  storage_tier                 = "P4"              # Standard performance
  backup_retention_days        = 7                 # Minimum backup retention
  geo_redundant_backup_enabled = false             # Cost optimization
  
  administrator_login          = var.admin_username
  administrator_password       = local.admin_password
  
  # Network settings
  public_network_access_enabled = true  # We'll restrict this later
  
  tags = {
    Environment = var.environment
    Component   = "database"
    ManagedBy   = "OpenTofu"
  }
}

# Database
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Firewall rule to allow Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Store connection string in Key Vault
resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "database-connection-string"
  value        = "postgresql://${var.admin_username}:${local.admin_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${var.database_name}?sslmode=require"
  key_vault_id = var.key_vault_id

  tags = {
    Environment = var.environment
    Component   = "database"
  }
}

# Store individual components
resource "azurerm_key_vault_secret" "db_host" {
  name         = "database-host"
  value        = azurerm_postgresql_flexible_server.main.fqdn
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "db_username" {
  name         = "database-username"
  value        = var.admin_username
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "database-password"
  value        = local.admin_password
  key_vault_id = var.key_vault_id
}

# Outputs
output "server_fqdn" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}

output "database_name" {
  value = azurerm_postgresql_flexible_server_database.main.name
}

output "connection_string_secret_name" {
  value = azurerm_key_vault_secret.db_connection_string.name
}