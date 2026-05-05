# Private Endpoint for AMPLS
resource "azurerm_private_endpoint" "ampls" {
  name                = "${var.ampls_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.ampls_name}-psc"
    private_connection_resource_id = azurerm_monitor_private_link_scope.main.id
    is_manual_connection           = false
    subresource_names              = ["azuremonitor"]
  }

  private_dns_zone_group {
    name = "ampls-dns-zone-group"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.monitor.id,
      azurerm_private_dns_zone.oms.id,
      azurerm_private_dns_zone.ods.id,
      azurerm_private_dns_zone.agentsvc.id,
      azurerm_private_dns_zone.blob.id
    ]
  }

  tags = var.tags
}

# Network Interface for Private Endpoint
data "azurerm_network_interface" "ampls_pe_nic" {
  name                = azurerm_private_endpoint.ampls.network_interface[0].name
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_private_endpoint.ampls]
}
