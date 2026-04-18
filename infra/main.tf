###############################################################################
# Azure SaaS Blueprint — root Terraform module.
#
# What lives here:
#   - Key Vault                       (all secrets; RBAC auth; soft-delete + purge-protect)
#   - Linux App Service Plan + App    (System-Assigned Managed Identity, TLS 1.2, HTTPS-only)
#   - Role assignment                 (App  --Key Vault Secrets User-->  Key Vault)
#   - Module: Azure SQL with RLS      (per-tenant Row-Level Security)
#
# What deliberately does NOT live here:
#   - Subscriptions / tenant creation        (out-of-band, one-time)
#   - Resource groups                        (managed by an RG module per env)
#   - Long-lived service-principal secrets   (we use OIDC federated login)
###############################################################################

terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.95"
    }
  }

  # Remote state in an Azure Storage Account. The backend config
  # is injected at `terraform init` time from the CI pipeline so
  # the same root module serves dev / staging / prod.
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

data "azurerm_client_config" "current" {}

# ---------- Key Vault -------------------------------------------------------
# RBAC-only (no access policies). Soft-delete + purge-protect ON so an
# accidental `terraform destroy` can't nuke tenant secrets.
resource "azurerm_key_vault" "kv" {
  name                       = "${var.prefix}-${var.env_name}-kv"
  location                   = var.location
  resource_group_name        = var.resource_group
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  tags = var.tags
}

# ---------- App Service Plan + App ------------------------------------------
resource "azurerm_service_plan" "plan" {
  name                = "${var.prefix}-${var.env_name}-plan"
  location            = var.location
  resource_group_name = var.resource_group
  os_type             = "Linux"
  sku_name            = var.plan_sku

  tags = var.tags
}

resource "azurerm_linux_web_app" "app" {
  name                = "${var.prefix}-${var.env_name}-app"
  location            = var.location
  resource_group_name = var.resource_group
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"
    always_on           = true

    application_stack {
      node_version = "20-lts"
    }
  }

  app_settings = {
    # The app reads secrets via Key Vault references, not env-injected literals.
    KEY_VAULT_NAME           = azurerm_key_vault.kv.name
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  tags = var.tags
}

# ---------- RBAC: App  -->  Key Vault Secrets User --------------------------
# Built-in role ID for "Key Vault Secrets User" is
# 4633458b-17de-408a-b874-0445c86b69e6 — we use the friendly name so
# `terraform plan` output is readable.
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

# ---------- Azure SQL with Row-Level Security -------------------------------
module "sql_rls" {
  source = "./modules/sql-rls"

  prefix                    = var.prefix
  env_name                  = var.env_name
  location                  = var.location
  resource_group            = var.resource_group
  key_vault_id              = azurerm_key_vault.kv.id
  enable_row_level_security = true
  tags                      = var.tags
}
