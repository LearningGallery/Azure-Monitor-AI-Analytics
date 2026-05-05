variable "storage_account_name" {
  description = "Storage account name (must be globally unique)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 characters, lowercase letters and numbers only"
  }
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "replication_type" {
  description = "Storage replication type"
  type        = string
  default     = "LRS"
}

variable "account_kind" {
  description = "Storage account kind"
  type        = string
  default     = "StorageV2"
}

variable "min_tls_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "TLS1_2"
}

variable "enable_https_traffic_only" {
  description = "Force HTTPS only"
  type        = bool
  default     = true
}

variable "allow_nested_items_to_be_public" {
  description = "Allow public blob access"
  type        = bool
  default     = false
}

variable "containers" {
  description = "Blob containers to create"
  type = map(object({
    name        = string
    access_type = string
  }))
  default = {
    logs = {
      name        = "logs"
      access_type = "private"
    }
    reports = {
      name        = "reports"
      access_type = "private"
    }
  }
}

variable "enable_lifecycle_management" {
  description = "Enable lifecycle management policy"
  type        = bool
  default     = false
}

variable "lifecycle_rules" {
  description = "Lifecycle management rules"
  type = map(object({
    enabled = bool
    filters = object({
      prefix_match = list(string)
      blob_types   = list(string)
    })
    actions = object({
      base_blob = map(number)
    })
  }))
  default = {}
}

variable "subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
  default     = null
}

variable "vnet_id" {
  description = "VNet ID for DNS zone link"
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "enable_private_endpoint" {
  type        = bool
  description = "Whether to enable a private endpoint for the storage account"
  default     = false
}