output "environment_id" {
  description = "Container Apps environment ID"
  value       = azurerm_container_app_environment.main.id
}

output "apps_fqdn" {
  description = "Container apps FQDNs"
  value = {
    for k, v in azurerm_container_app.apps : k => v.latest_revision_fqdn
  }
}

output "system_assigned_identity_principal_id" {
  description = "System assigned identity principal ID"
  value       = azurerm_container_app.apps["ai_api"].identity[0].principal_id
}
