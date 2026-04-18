variable "env_name" {
  description = "Environment: dev | staging | prod"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.env_name)
    error_message = "env_name must be one of: dev, staging, prod."
  }
}

variable "prefix" {
  description = "Short project prefix — used in resource names."
  type        = string
  default     = "tenantapp"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "resource_group" {
  description = "Existing resource group to deploy into."
  type        = string
}

variable "plan_sku" {
  description = "App Service Plan SKU — P1v3 for prod, B2 for dev."
  type        = string
  default     = "P1v3"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    project = "azure-saas-blueprint"
    owner   = "nirmit.dagli"
    managed = "terraform"
  }
}
