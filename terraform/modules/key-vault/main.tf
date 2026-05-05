data "azurerm_client_config" "current" {}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id

  sku_name = var.sku_name

  enabled_for_deployment          = var.enabled_for_deployment
  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  enabled_for_template_deployment = var.enabled_for_template_deployment
  enable_rbac_authorization       = var.enable_rbac_authorization

  purge_protection_enabled   = var.purge_protection_enabled
  soft_delete_retention_days = var.soft_delete_retention_days

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = var.tags
}

# Private Endpoint
resource "azurerm_private_endpoint" "kv" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = "${var.key_vault_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.key_vault_name}-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv[0].id]
  }

  tags = var.tags
}

# Private DNS Zone
resource "azurerm_private_dns_zone" "kv" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# DNS Zone VNet Link
resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  count = var.enable_private_endpoint ? 1 : 0

  name                  = "${var.key_vault_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv[0].name
  virtual_network_id    = var.vnet_id

  tags = var.tags
}

# RBAC Role Assignments (if RBAC is enabled)
resource "azurerm_role_assignment" "kv_admin" {
  count = var.enable_rbac_authorization ? 1 : 0

  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}
