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
