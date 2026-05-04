variable "windows_vms" {
  description = "List of Windows VMs to monitor"
  type = list(object({
    name = string
    id   = string
  }))
  default = []
}

variable "linux_vms" {
  description = "List of Linux VMs to monitor"
  type = list(object({
    name = string
    id   = string
  }))
  default = []
}

variable "windows_vmss" {
  description = "List of Windows VM Scale Sets to monitor"
  type = list(object({
    name = string
    id   = string
  }))
  default = []
}

variable "linux_vmss" {
  description = "List of Linux VM Scale Sets to monitor"
  type = list(object({
    name = string
    id   = string
  }))
  default = []
}

variable "workspace_customer_id" {
  description = "Log Analytics Workspace Customer ID"
  type        = string
  sensitive   = true
}

variable "workspace_primary_key" {
  description = "Log Analytics Workspace Primary Key"
  type        = string
  sensitive   = true
}

variable "data_collection_rule_id" {
  description = "Data Collection Rule ID"
  type        = string
}

variable "enable_service_map" {
  description = "Enable Dependency Agent for Service Map"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
