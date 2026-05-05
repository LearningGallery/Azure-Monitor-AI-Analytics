output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.main.name
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value = {
    for k, v in azurerm_subnet.subnets : k => v.id
  }
}

output "subnet_names" {
  description = "Map of subnet keys to names"
  value = {
    for k, v in azurerm_subnet.subnets : k => v.name
  }
}

output "nsg_ids" {
  description = "Map of NSG names to IDs"
  value = {
    for k, v in azurerm_network_security_group.main : k => v.id
  }
}
