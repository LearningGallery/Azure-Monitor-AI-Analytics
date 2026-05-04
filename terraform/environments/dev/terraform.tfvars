project_name     = "ailoganalytics"
environment      = "dev"
location         = "southeastasia"
cost_center      = "IT-Development"
owner_email      = "your.email@company.com"

# Networking
vnet_address_space = ["10.10.0.0/16"]

# Log Analytics
log_retention_days = 30
daily_quota_gb     = 5  # Dev environment

# AKS
aks_vm_size   = "Standard_D2s_v3"  # Smaller for dev
aks_min_nodes = 1
aks_max_nodes = 3

# Features
enable_geo_redundancy = false
enable_prometheus     = false  # Disable for dev to save costs

# Container Registry
acr_name = "yourcompanyacr"  # Replace with your ACR name

tags = {
  Department = "Engineering"
  Project    = "Log Analytics AI"
}
