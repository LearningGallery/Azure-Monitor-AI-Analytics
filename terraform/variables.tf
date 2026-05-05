variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ailoganalytics"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "location" {
  description = "Primary Azure region"
  type        = string
  default     = "southeastasia" # Singapore
}

variable "secondary_location" {
  description = "Secondary Azure region for geo-redundancy"
  type        = string
  default     = "eastasia" # Hong Kong
}

variable "enable_geo_redundancy" {
  description = "Enable geo-redundant Log Analytics workspace"
  type        = bool
  default     = false
}

variable "vnet_address_space" {
  description = "VNet address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 90

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Retention must be between 30 and 730 days"
  }
}

variable "daily_quota_gb" {
  description = "Daily ingestion quota in GB (-1 for unlimited)"
  type        = number
  default     = 10 # 10GB per day for cost control
}

variable "aks_vm_size" {
  description = "AKS node VM size"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "aks_min_nodes" {
  description = "Minimum number of AKS nodes"
  type        = number
  default     = 1
}

variable "aks_max_nodes" {
  description = "Maximum number of AKS nodes"
  type        = number
  default     = 5
}

variable "enable_prometheus" {
  description = "Enable Azure Monitor Managed Prometheus"
  type        = bool
  default     = true
}

variable "acr_name" {
  description = "Azure Container Registry name"
  type        = string
}

variable "huggingface_api_key" {
  description = "HuggingFace API key"
  type        = string
  sensitive   = true
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "IT-Infrastructure"
}

variable "owner_email" {
  description = "Owner email for notifications"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
