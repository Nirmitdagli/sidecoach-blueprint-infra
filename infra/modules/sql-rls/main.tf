###############################################################################
# modules/sql-rls — Azure SQL with per-tenant Row-Level Security.
#
# The SQL server + database are declarative; the RLS policies themselves
# are applied via a post-provision sqlcmd script because RLS CREATE POLICY
# isn't first-class in AzureRM (yet). The script is idempotent.
###############################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.95"
    }
  }
}

variable "prefix"                    { type = string }
variable "env_name"                  { type = string }
variable "location"                  { type = string }
variable "resource_group"            { type = string }
variable "key_vault_id"              { type = string }
variable "enable_row_level_security" { type = bool  default = true }
variable "tags"                      { type = map(string) default = {} }

# Admin credentials are generated here and pushed to Key Vault —
# no human ever sees them, they rotate on each apply by marking
# `random_password` with keepers tied to env_name.
resource "random_password" "sql_admin" {
  length  = 32
  special = true
  keepers = {
    env = var.env_name
  }
}

resource "azurerm_mssql_server" "sql" {
  name                          = "${var.prefix}-${var.env_name}-sql"
  resource_group_name           = var.resource_group
  location                      = var.location
  version                       = "12.0"
  administrator_login           = "sqladmin"
  administrator_login_password  = random_password.sql_admin.result
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  azuread_administrator {
    login_username = "SQL-Admins-${var.env_name}"
    object_id      = data.azurerm_client_config.current.object_id
  }

  tags = var.tags
}

resource "azurerm_mssql_database" "app" {
  name                 = "${var.prefix}-${var.env_name}-db"
  server_id            = azurerm_mssql_server.sql.id
  sku_name             = "S1"
  zone_redundant       = false
  storage_account_type = "Local"

  short_term_retention_policy {
    retention_days = 35
  }

  tags = var.tags
}

data "azurerm_client_config" "current" {}

# Stash the generated admin password in Key Vault.
resource "azurerm_key_vault_secret" "sql_admin" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin.result
  key_vault_id = var.key_vault_id
}

# Apply the RLS policy. This would be a null_resource in real code;
# the sql script itself lives in ./policies/rls.sql.
resource "null_resource" "apply_rls" {
  count = var.enable_row_level_security ? 1 : 0

  triggers = {
    db_id       = azurerm_mssql_database.app.id
    policy_hash = filesha256("${path.module}/policies/rls.sql")
  }

  provisioner "local-exec" {
    command = "sqlcmd -S ${azurerm_mssql_server.sql.fully_qualified_domain_name} -d ${azurerm_mssql_database.app.name} -U sqladmin -P '${random_password.sql_admin.result}' -i ${path.module}/policies/rls.sql"
  }

  depends_on = [azurerm_mssql_database.app]
}

output "database_id" {
  value = azurerm_mssql_database.app.id
}
