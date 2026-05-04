output "primary_workspace_id" {
  description = "Primary Log Analytics Workspace ID"
  value       = module.log_analytics_primary.workspace_id
}

output "primary_workspace_customer_id" {
  description = "Primary Workspace Customer ID"
  value       = module.log_analytics_primary.workspace_customer_id
  sensitive   = true
}

output "ampls_id" {
  description = "AMPLS ID"
  value       = module.ampls.ampls_id
}

output "ampls_private_ip" {
  description = "AMPLS Private Endpoint IP"
  value       = module.ampls.private_ip_address
}

output "aks_cluster_name" {
  description = "AKS Cluster Name"
  value       = module.aks.cluster_name
}

output "container_apps_fqdn" {
  description = "Container Apps FQDN"
  value       = module.container_apps.apps_fqdn
}

output "storage_account_name" {
  description = "Storage Account Name"
  value       = module.storage.storage_account_name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.key_vault.vault_uri
}

output "resource_group_name" {
  description = "Resource Group Name"
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.networking.vnet_id
}
