output "app_url" {
  description = "HTTPS URL of the deployed App Service."
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "key_vault_uri" {
  description = "Key Vault URI — the app pulls secrets from here via Managed Identity."
  value       = azurerm_key_vault.kv.vault_uri
}

output "app_principal_id" {
  description = "App Service's Managed Identity principal ID."
  value       = azurerm_linux_web_app.app.identity[0].principal_id
}
