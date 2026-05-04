output "ampls_id" {
  description = "AMPLS resource ID"
  value       = azurerm_monitor_private_link_scope.main.id
}

output "ampls_name" {
  description = "AMPLS name"
  value       = azurerm_monitor_private_link_scope.main.name
}

output "private_endpoint_id" {
  description = "Private Endpoint ID"
  value       = azurerm_private_endpoint.ampls.id
}

output "private_ip_address" {
  description = "Private IP address of the endpoint"
  value       = data.azurerm_network_interface.ampls_pe_nic.private_ip_address
}

output "dns_zone_ids" {
  description = "Private DNS Zone IDs"
  value = {
    monitor  = azurerm_private_dns_zone.monitor.id
    oms      = azurerm_private_dns_zone.oms.id
    ods      = azurerm_private_dns_zone.ods.id
    agentsvc = azurerm_private_dns_zone.agentsvc.id
    blob     = azurerm_private_dns_zone.blob.id
  }
}
