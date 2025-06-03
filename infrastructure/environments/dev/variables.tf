variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Sweden Central"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "weather-monitoring"
}