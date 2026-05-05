# AMPLS Resource
resource "azurerm_monitor_private_link_scope" "main" {
  name                = var.ampls_name
  resource_group_name = var.resource_group_name

  # Ingestion access mode
  ingestion_access_mode = var.ingestion_access_mode # "Open" or "PrivateOnly"

  # Query access mode
  query_access_mode = var.query_access_mode # "Open" or "PrivateOnly"

  tags = var.tags
}

# Link Log Analytics Workspaces to AMPLS
resource "azurerm_monitor_private_link_scoped_service" "workspaces" {
  # Filter the map to remove null values
  for_each = var.workspace_ids

  name                = "ampls-link-${each.key}"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.main.name
  linked_resource_id  = each.value
}

# Link Application Insights
resource "azurerm_monitor_private_link_scoped_service" "app_insights" {
  for_each = toset(var.app_insights_ids)

  name                = "ampls-link-ai-${replace(each.value, "/", "-")}"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.main.name
  linked_resource_id  = each.value
}

# Link Data Collection Endpoints
resource "azurerm_monitor_private_link_scoped_service" "dce" {
  for_each = var.data_collection_endpoint_ids

  name                = "ampls-link-dce-${each.key}"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.main.name
  linked_resource_id  = each.value
}
