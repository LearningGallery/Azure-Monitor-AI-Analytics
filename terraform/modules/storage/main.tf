# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type
  account_kind             = var.account_kind
  
  min_tls_version                 = var.min_tls_version
  enable_https_traffic_only       = var.enable_https_traffic_only
  allow_nested_items_to_be_public = var.allow_nested_items_to_be_public
  
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 7
    }
    
    container_delete_retention_policy {
      days = 7
    }
  }
  
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
  
  tags = var.tags
}

# Blob Containers
resource "azurerm_storage_container" "containers" {
  for_each = var.containers
  
  name                  = each.value.name
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = each.value.access_type
}

# Management Policy (Lifecycle)
resource "azurerm_storage_management_policy" "main" {
  count = var.enable_lifecycle_management ? 1 : 0
  
  storage_account_id = azurerm_storage_account.main.id
  
  dynamic "rule" {
    for_each = var.lifecycle_rules
    
    content {
      name    = rule.key
      enabled = rule.value.enabled
      
      filters {
        prefix_match = rule.value.filters.prefix_match
        blob_types   = rule.value.filters.blob_types
      }
      
      actions {
        base_blob {
          tier_to_cool_after_days_since_modification_greater_than    = lookup(rule.value.actions.base_blob, "tier_to_cool_after_days", null)
          tier_to_archive_after_days_since_modification_greater_than = lookup(rule.value.actions.base_blob, "tier_to_archive_after_days", null)
          delete_after_days_since_modification_greater_than          = lookup(rule.value.actions.base_blob, "delete_after_days", null)
        }
      }
    }
  }
}

# Private Endpoint
resource "azurerm_private_endpoint" "storage" {
  count = var.subnet_id != null ? 1 : 0
  
  name                = "${var.storage_account_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  
  private_service_connection {
    name                           = "${var.storage_account_name}-psc"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
  
  private_dns_zone_group {
    name                 = "storage-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage.id]
  }
  
  tags = var.tags
}

# Private DNS Zone
resource "azurerm_private_dns_zone" "storage" {
  count = var.subnet_id != null ? 1 : 0
  
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# DNS Zone VNet Link
resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  count = var.subnet_id != null && var.vnet_id != null ? 1 : 0
  
  name                  = "${var.storage_account_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage.name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}
