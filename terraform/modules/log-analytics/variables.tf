variable "workspace_name" {
  description = "Name of the Log Analytics Workspace"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "resource_group_id" {
  description = "Resource group ID"
  type        = string
}

variable "sku" {
  description = "Workspace SKU"
  type        = string
  default     = "PerGB2018"
  
  validation {
    condition     = contains(["Free", "PerGB2018", "PerNode", "Premium", "Standard", "Standalone", "Unlimited", "CapacityReservation"], var.sku)
    error_message = "SKU must be a valid Log Analytics SKU"
  }
}

variable "retention_days" {
  description = "Log retention in days (30-730)"
  type        = number
  default     = 90
  
  validation {
    condition     = var.retention_days >= 30 && var.retention_days <= 730
    error_message = "Retention must be between 30 and 730 days"
  }
}

variable "daily_quota_gb" {
  description = "Daily ingestion quota in GB (-1 for unlimited)"
  type        = number
  default     = -1
}

variable "reservation_capacity_gb" {
  description = "Daily capacity reservation in GB (100, 200, 300, ...)"
  type        = number
  default     = null
}

variable "internet_ingestion_enabled" {
  description = "Enable public ingestion endpoint"
  type        = bool
  default     = false
}

variable "internet_query_enabled" {
  description = "Enable public query endpoint"
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Enable public network access for DCE"
  type        = bool
  default     = false
}

variable "solutions" {
  description = "List of solutions to enable"
  type        = list(string)
  default = [
    "Security",
    "Updates",
    "VMInsights",
    "ContainerInsights",
    "ServiceMap",
    "AzureActivity",
    "ChangeTracking",
    "SecurityInsights"  # Sentinel
  ]
}

variable "enable_archive" {
  description = "Enable long-term archival to storage"
  type        = bool
  default     = true
}

variable "archive_storage_account_id" {
  description = "Storage account ID for archival"
  type        = string
  default     = null
}

variable "create_query_pack" {
  description = "Create a query pack for shared queries"
  type        = bool
  default     = true
}

variable "saved_searches" {
  description = "Map of saved searches"
  type = map(object({
    category     = string
    display_name = string
    query        = string
  }))
  default = {}
}

variable "enable_container_insights" {
  description = "Enable Container Insights DCR"
  type        = bool
  default     = true
}

variable "monitored_namespaces" {
  description = "Kubernetes namespaces to monitor"
  type        = list(string)
  default     = ["default", "kube-system", "production"]
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
