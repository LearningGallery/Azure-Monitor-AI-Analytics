# Log Analytics Workspace with enterprise features
resource "azurerm_log_analytics_workspace" "main" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name

  # SKU - PerGB2018 is standard for enterprise
  sku = var.sku

  # Retention (30-730 days, default 30)
  retention_in_days = var.retention_days

  # Daily quota in GB (optional, for cost control)
  daily_quota_gb = var.daily_quota_gb

  # Workspace features
  internet_ingestion_enabled = var.internet_ingestion_enabled
  internet_query_enabled     = var.internet_query_enabled

  # Reservation capacity commitment (cost savings)
  reservation_capacity_in_gb_per_day = var.reservation_capacity_gb

  # Data export (for long-term archival)
  # Requires Storage Account

  tags = merge(
    var.tags,
    {
      "Purpose"     = "Enterprise Log Analytics"
      "Environment" = var.environment
      "ManagedBy"   = "Terraform"
    }
  )
}

# Workspace Solutions (pre-built analytics)
resource "azurerm_log_analytics_solution" "solutions" {
  for_each = toset(var.solutions)

  solution_name         = each.value
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/${each.value}"
  }

  tags = var.tags
}

# Linked Storage Account (for long-term retention)
resource "azurerm_log_analytics_linked_storage_account" "archive" {
  count = var.enable_archive ? 1 : 0

  data_source_type      = "CustomLogs"
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  storage_account_ids   = [var.archive_storage_account_id]
}

# Saved Searches (common queries)
resource "azurerm_log_analytics_saved_search" "common_queries" {
  for_each = var.saved_searches

  name                       = each.key
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  category                   = each.value.category
  display_name               = each.value.display_name
  query                      = each.value.query

  tags = var.tags
}

# Query Pack (shared queries across organization)
resource "azurerm_log_analytics_query_pack" "enterprise" {
  count = var.create_query_pack ? 1 : 0

  name                = "${var.workspace_name}-querypack"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}
