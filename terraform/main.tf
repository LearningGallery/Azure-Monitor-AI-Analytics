locals {
  common_tags = {
    Project     = "AI Log Analytics"
    ManagedBy   = "Terraform"
    Environment = var.environment
    CostCenter  = var.cost_center
    Owner       = var.owner_email
  }
  
  # Naming convention
  prefix = "\${var.project_name}-\${var.environment}"
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "\${local.prefix}-rg"
  location = var.location
  
  tags = local.common_tags
}

# Networking Module
module "networking" {
  source = "./modules/networking"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  vnet_name           = "\${local.prefix}-vnet"
  address_space       = var.vnet_address_space
  
  subnets = {
    monitoring = {
      name             = "snet-monitoring"
      address_prefixes = [cidrsubnet(var.vnet_address_space, 4, 0)]
      service_endpoints = [
        "Microsoft.Storage",
        "Microsoft.KeyVault",
        "Microsoft.ContainerRegistry"
      ]
      private_endpoint_network_policies_enabled = false
    }
    aks = {
      name             = "snet-aks"
      address_prefixes = [cidrsubnet(var.vnet_address_space, 2, 1)]
      service_endpoints = [
        "Microsoft.Storage",
        "Microsoft.ContainerRegistry"
      ]
    }
    vms = {
      name             = "snet-vms"
      address_prefixes = [cidrsubnet(var.vnet_address_space, 4, 1)]
    }
    containers = {
      name             = "snet-containers"
      address_prefixes = [cidrsubnet(var.vnet_address_space, 4, 2)]
      delegation = {
        name = "Microsoft.App/environments"
        service_delegation = {
          name = "Microsoft.App/environments"
          actions = [
            "Microsoft.Network/virtualNetworks/subnets/join/action"
          ]
        }
      }
    }
  }
  
  tags = local.common_tags
}

# Storage Account for Log Archives
module "storage" {
  source = "./modules/storage"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  storage_account_name = "\${replace(local.prefix, "-", "")}sa"
  
  # Security settings
  enable_https_traffic_only       = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  
  # Private endpoint
  subnet_id = module.networking.subnet_ids["monitoring"]
  vnet_id   = module.networking.vnet_id
  
  # Lifecycle management for cost optimization
  enable_lifecycle_management = true
  lifecycle_rules = {
    archive_old_logs = {
      enabled = true
      filters = {
        prefix_match = ["logs/"]
        blob_types   = ["blockBlob"]
      }
      actions = {
        base_blob = {
          tier_to_cool_after_days    = 30
          tier_to_archive_after_days = 90
          delete_after_days          = 730  # 2 years
        }
      }
    }
  }
  
  tags = local.common_tags
}

# Key Vault for Secrets
module "key_vault" {
  source = "./modules/key-vault"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  key_vault_name      = "\${local.prefix}-kv"
  
  # Permissions
  tenant_id = data.azurerm_client_config.current.tenant_id
  
  # Private endpoint
  subnet_id = module.networking.subnet_ids["monitoring"]
  vnet_id   = module.networking.vnet_id
  
  # RBAC mode (recommended over access policies)
  enable_rbac_authorization = true
  
  # Security
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
  
  tags = local.common_tags
}

# Log Analytics Workspace (Primary)
module "log_analytics_primary" {
  source = "./modules/log-analytics"
  
  workspace_name      = "\${local.prefix}-law-primary"
  resource_group_name = azurerm_resource_group.main.name
  resource_group_id   = azurerm_resource_group.main.id
  location            = var.location
  
  # Enterprise settings
  sku                        = "PerGB2018"
  retention_days             = var.log_retention_days
  daily_quota_gb             = var.daily_quota_gb
  reservation_capacity_gb    = var.environment == "prod" ? 100 : null
  
  # Security - Disable public access
  internet_ingestion_enabled     = false
  internet_query_enabled         = false
  public_network_access_enabled  = false
  
  # Solutions
  solutions = [
    "Security",
    "Updates",
    "VMInsights",
    "ContainerInsights",
    "ServiceMap",
    "AzureActivity",
    "ChangeTracking",
    "SecurityInsights"
  ]
  
  # Archive to storage
  enable_archive              = true
  archive_storage_account_id  = module.storage.storage_account_id
  
  # Query pack
  create_query_pack = true
  
  # Saved searches
  saved_searches = {
    failed_login_attempts = {
      category     = "Security"
      display_name = "Failed Login Attempts (Last 24h)"
      query        = file("\${path.module}/../kql/queries/security/failed-logins.kql")
    }
    high_cpu_vms = {
      category     = "Performance"
      display_name = "VMs with High CPU Usage"
      query        = file("\${path.module}/../kql/queries/vm-insights/performance.kql")
    }
    aks_pod_failures = {
      category     = "Containers"
      display_name = "AKS Pod Failures"
      query        = file("\${path.module}/../kql/queries/aks/pod-failures.kql")
    }
  }
  
  # Container Insights
  enable_container_insights = true
  monitored_namespaces      = ["default", "kube-system", "production", "monitoring"]
  
  environment = var.environment
  tags        = local.common_tags
}

# Log Analytics Workspace (Secondary - for geo-redundancy)
module "log_analytics_secondary" {
  count = var.enable_geo_redundancy ? 1 : 0
  
  source = "./modules/log-analytics"
  
  workspace_name      = "\${local.prefix}-law-secondary"
  resource_group_name = azurerm_resource_group.main.name
  resource_group_id   = azurerm_resource_group.main.id
  location            = var.secondary_location
  
  # Same settings as primary
  sku                        = "PerGB2018"
  retention_days             = var.log_retention_days
  internet_ingestion_enabled = false
  internet_query_enabled     = false
  
  solutions             = ["Security", "AzureActivity"]
  enable_archive        = true
  archive_storage_account_id = module.storage.storage_account_id
  
  environment = var.environment
  tags        = local.common_tags
}

# AMPLS (Azure Monitor Private Link Scope)
module "ampls" {
  source = "./modules/ampls"
  
  ampls_name          = "\${local.prefix}-ampls"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  
  # Private endpoint configuration
  subnet_id = module.networking.subnet_ids["monitoring"]
  vnet_id   = module.networking.vnet_id
  
  # Linked resources
  workspace_ids = concat(
    [module.log_analytics_primary.workspace_id],
    var.enable_geo_redundancy ? [module.log_analytics_secondary.workspace_id] : []
  )
  
  data_collection_endpoint_ids = [
    module.log_analytics_primary.data_collection_endpoint_id
  ]
  
  # Access modes (PrivateOnly for maximum security)
  ingestion_access_mode = "PrivateOnly"
  query_access_mode     = "PrivateOnly"
  
  tags = local.common_tags
}

# AKS Cluster with Container Insights
module "aks" {
  source = "./modules/aks"
  
  cluster_name        = "\${local.prefix}-aks"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  dns_prefix          = local.prefix
  
  # Networking
  vnet_subnet_id = module.networking.subnet_ids["aks"]
  network_plugin = "azure"
  network_policy = "azure"
  
  # Node pool
  default_node_pool = {
    name                = "system"
    vm_size             = var.aks_vm_size
    enable_auto_scaling = true
    min_count           = var.aks_min_nodes
    max_count           = var.aks_max_nodes
    os_disk_size_gb     = 128
    type                = "VirtualMachineScaleSets"
  }
  
  # Monitoring
  log_analytics_workspace_id = module.log_analytics_primary.workspace_id
  
  # Container Insights DCR
  data_collection_rule_id = module.log_analytics_primary.dcr_container_insights_id
  
  # Azure Monitor Managed Prometheus (optional)
  enable_prometheus = var.enable_prometheus
  
  # Identity
  identity_type = "SystemAssigned"
  
  # Security
  azure_policy_enabled             = true
  role_based_access_control_enabled = true
  
  tags = local.common_tags
}

# Container Apps Environment (for AI API)
module "container_apps" {
  source = "./modules/container-apps"
  
  environment_name    = "\${local.prefix}-containerenv"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  
  # Networking
  subnet_id                      = module.networking.subnet_ids["containers"]
  internal_load_balancer_enabled = true
  
  # Monitoring
  log_analytics_workspace_id = module.log_analytics_primary.workspace_id
  
  # Container Apps
  apps = {
    ai_api = {
      name     = "ai-log-api"
      image    = "\${var.acr_name}.azurecr.io/ai-log-api:latest"
      cpu      = 1.0
      memory   = "2Gi"
      min_replicas = 1
      max_replicas = 10
      
      env = [
        {
          name  = "AZURE_LOG_ANALYTICS_WORKSPACE_ID"
          value = module.log_analytics_primary.workspace_customer_id
        },
        {
          name        = "AZURE_LOG_ANALYTICS_KEY"
          secret_name = "law-primary-key"
        },
        {
          name        = "HUGGINGFACE_API_KEY"
          secret_name = "hf-api-key"
        }
      ]
      
      secrets = [
        {
          name  = "law-primary-key"
          value = module.log_analytics_primary.primary_shared_key
        },
        {
          name  = "hf-api-key"
          value = var.huggingface_api_key
        }
      ]
    }
  }
  
  tags = local.common_tags
}

# Diagnostic Settings for Azure Resources
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "aks-diagnostics"
  target_resource_id         = module.aks.cluster_id
  log_analytics_workspace_id = module.log_analytics_primary.workspace_id
  
  dynamic "enabled_log" {
    for_each = [
      "kube-apiserver",
      "kube-controller-manager",
      "kube-scheduler",
      "kube-audit",
      "cluster-autoscaler",
      "guard"
    ]
    
    content {
      category = enabled_log.value
    }
  }
  
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "storage-diagnostics"
  target_resource_id         = "\${module.storage.storage_account_id}/blobServices/default"
  log_analytics_workspace_id = module.log_analytics_primary.workspace_id
  
  enabled_log {
    category = "StorageRead"
  }
  
  enabled_log {
    category = "StorageWrite"
  }
  
  enabled_log {
    category = "StorageDelete"
  }
  
  metric {
    category = "Transaction"
    enabled  = true
  }
}

# Data Sources
data "azurerm_client_config" "current" {}
