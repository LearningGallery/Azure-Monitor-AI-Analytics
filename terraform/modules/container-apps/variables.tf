variable "environment_name" {
  description = "Container Apps environment name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Container Apps"
  type        = string
}

variable "internal_load_balancer_enabled" {
  description = "Enable internal load balancer"
  type        = bool
  default     = false
}

variable "apps" {
  description = "Container apps configuration"
  type = map(object({
    name         = string
    image        = string
    cpu          = number
    memory       = string
    min_replicas = number
    max_replicas = number
    env = list(object({
      name        = string
      value       = optional(string)
      secret_name = optional(string)
    }))
    secrets = list(object({
      name  = string
      value = string
    }))
  }))
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
