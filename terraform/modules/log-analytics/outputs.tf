output "workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.main.id
}

output "workspace_name" {
  description = "Log Analytics Workspace name"
  value       = azurerm_log_analytics_workspace.main.name
}

output "workspace_customer_id" {
  description = "Workspace Customer ID (for agent configuration)"
  value       = azurerm_log_analytics_workspace.main.workspace_id
  sensitive   = true
}

output "primary_shared_key" {
  description = "Primary shared key"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}

output "secondary_shared_key" {
  description = "Secondary shared key"
  value       = azurerm_log_analytics_workspace.main.secondary_shared_key
  sensitive   = true
}

output "data_collection_endpoint_id" {
  description = "Data Collection Endpoint ID"
  value       = azurerm_monitor_data_collection_endpoint.main.id
}

output "dcr_vm_insights_id" {
  description = "VM Insights DCR ID"
  value       = azurerm_monitor_data_collection_rule.vm_insights.id
}

output "dcr_container_insights_id" {
  description = "Container Insights DCR ID"
  value       = var.enable_container_insights ? azurerm_monitor_data_collection_rule.container_insights[0].id : null
}
