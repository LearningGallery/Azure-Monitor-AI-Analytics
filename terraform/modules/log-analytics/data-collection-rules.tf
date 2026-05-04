# Data Collection Endpoint (required for DCR)
resource "azurerm_monitor_data_collection_endpoint" "main" {
  name                          = "\${var.workspace_name}-dce"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  kind                          = "Linux"  # or "Windows"
  public_network_access_enabled = var.public_network_access_enabled
  
  tags = var.tags
}

# Data Collection Rule for VMs (OS logs)
resource "azurerm_monitor_data_collection_rule" "vm_insights" {
  name                        = "dcr-vm-insights-\${var.environment}"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.main.id
  
  # Windows Event Logs
  data_sources {
    windows_event_log {
      name    = "eventLogsDataSource"
      streams = ["Microsoft-Event"]
      
      x_path_queries = [
        "System!*[System[(Level=1 or Level=2 or Level=3)]]",
        "Application!*[System[(Level=1 or Level=2 or Level=3)]]",
        "Security!*"
      ]
    }
    
    # Syslog (Linux)
    syslog {
      name    = "syslogDataSource"
      streams = ["Microsoft-Syslog"]
      
      facility_names = [
        "auth",
        "authpriv",
        "cron",
        "daemon",
        "kern",
        "syslog",
        "user"
      ]
      
      log_levels = [
        "Critical",
        "Alert",
        "Emergency",
        "Error",
        "Warning"
      ]
    }
    
    # Performance Counters
    performance_counter {
      name                          = "perfCounterDataSource"
      streams                       = ["Microsoft-Perf", "Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 60
      
      counter_specifiers = [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available Bytes",
        "\\Memory\\% Committed Bytes In Use",
        "\\LogicalDisk(_Total)\\% Free Space",
        "\\LogicalDisk(_Total)\\Disk Transfers/sec",
        "\\Network Interface(*)\\Bytes Total/sec"
      ]
    }
  }
  
  # Destinations
  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = "logAnalyticsDestination"
    }
  }
  
  # Data Flow
  data_flow {
    streams      = ["Microsoft-Event", "Microsoft-Syslog", "Microsoft-Perf", "Microsoft-InsightsMetrics"]
    destinations = ["logAnalyticsDestination"]
  }
  
  tags = var.tags
}

# DCR for AKS/Container Insights
resource "azurerm_monitor_data_collection_rule" "container_insights" {
  count = var.enable_container_insights ? 1 : 0
  
  name                        = "dcr-container-insights-\${var.environment}"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.main.id
  
  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = ["Microsoft-ContainerLog", "Microsoft-ContainerLogV2", "Microsoft-KubeEvents", "Microsoft-KubePodInventory"]
      
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Include"
          namespaces             = var.monitored_namespaces
          enableContainerLogV2   = true
        }
      })
    }
  }
  
  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = "containerInsightsDestination"
    }
  }
  
  data_flow {
    streams      = ["Microsoft-ContainerLog", "Microsoft-ContainerLogV2", "Microsoft-KubeEvents", "Microsoft-KubePodInventory"]
    destinations = ["containerInsightsDestination"]
  }
  
  tags = var.tags
}

# DCR for Azure Monitor Agent (AMA)
resource "azapi_resource" "dcr_custom_logs" {
  type      = "Microsoft.Insights/dataCollectionRules@2022-06-01"
  name      = "dcr-custom-logs-\${var.environment}"
  location  = var.location
  parent_id = var.resource_group_id
  
  body = jsonencode({
    properties = {
      dataCollectionEndpointId = azurerm_monitor_data_collection_endpoint.main.id
      
      dataSources = {
        # Custom logs via REST API
        logFiles = [
          {
            name    = "customAppLogs"
            streams = ["Custom-ApplicationLogs"]
            
            filePatterns = [
              "/var/log/myapp/*.log"
            ]
            
            format = "text"
            
            settings = {
              text = {
                recordStartTimestampFormat = "ISO 8601"
              }
            }
          }
        ]
      }
      
      destinations = {
        logAnalytics = [
          {
            workspaceResourceId = azurerm_log_analytics_workspace.main.id
            name                = "customLogsDestination"
          }
        ]
      }
      
      dataFlows = [
        {
          streams      = ["Custom-ApplicationLogs"]
          destinations = ["customLogsDestination"]
          
          transformKql = "source | where Level == 'Error' or Level == 'Critical'"
          outputStream = "Custom-ApplicationLogs-CL"
        }
      ]
    }
  })
  
  tags = var.tags
}
