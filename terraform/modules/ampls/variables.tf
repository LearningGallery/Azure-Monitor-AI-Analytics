variable "ampls_name" {
  description = "Name of the Azure Monitor Private Link Scope"
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

variable "subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network ID"
  type        = string
}

variable "workspace_ids" {
  description = "List of Log Analytics Workspace IDs to link"
  type        = list(string)
  default     = []
}

variable "app_insights_ids" {
  description = "List of Application Insights IDs to link"
  type        = list(string)
  default     = []
}

variable "data_collection_endpoint_ids" {
  description = "List of Data Collection Endpoint IDs to link"
  type        = list(string)
  default     = []
}

variable "ingestion_access_mode" {
  description = "Ingestion access mode: Open or PrivateOnly"
  type        = string
  default     = "PrivateOnly"
  
  validation {
    condition     = contains(["Open", "PrivateOnly"], var.ingestion_access_mode)
    error_message = "Access mode must be either 'Open' or 'PrivateOnly'"
  }
}

variable "query_access_mode" {
  description = "Query access mode: Open or PrivateOnly"
  type        = string
  default     = "PrivateOnly"
  
  validation {
    condition     = contains(["Open", "PrivateOnly"], var.query_access_mode)
    error_message = "Access mode must be either 'Open' or 'PrivateOnly'"
  }
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
