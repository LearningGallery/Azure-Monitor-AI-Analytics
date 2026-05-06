# Data Collection Endpoint (required for Custom Logs)
resource "azurerm_monitor_data_collection_endpoint" "main" {
  name                          = "${var.workspace_name}-dce"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  kind                          = "Linux" # Using Linux for this environment
  public_network_access_enabled = var.public_network_access_enabled

  tags = var.tags
}

# Data Collection Rule for VMs (OS logs)
resource "azurerm_monitor_data_collection_rule" "vm_insights" {
  name                = "dcr-vm-insights-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  # REMOVED: data_collection_endpoint_id (Resolves the Windows/Linux DCE conflict for standard logs)

  data_sources {
    # REMOVED: windows_event_log (Since DCE is Linux, mixing OS types causes InvalidPayload)

    # Syslog (Linux)
    syslog {
      name    = "syslogDataSource"
      streams = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "cron", "daemon", "kern", "syslog", "user"]
      log_levels     = ["Critical", "Alert", "Emergency", "Error", "Warning"]
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

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = "logAnalyticsDestination"
    }
  }

  data_flow {
    # Removed Microsoft-Event to match the removed Windows data source
    streams      = ["Microsoft-Syslog", "Microsoft-Perf", "Microsoft-InsightsMetrics"]
    destinations = ["logAnalyticsDestination"]
  }

  tags = var.tags
}

# DCR for AKS/Container Insights
resource "azurerm_monitor_data_collection_rule" "container_insights" {
  count = var.enable_container_insights ? 1 : 0

  name                = "dcr-container-insights-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  # REMOVED: data_collection_endpoint_id (Container Insights does not support DCE linking here)

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

# DCR for Azure Monitor Agent (AMA) - Custom Logs
resource "azapi_resource" "dcr_custom_logs" {
  type       = "Microsoft.Insights/dataCollectionRules@2022-06-01"
  name       = "dcr-custom-logs-${var.environment}"
  location   = var.location
  parent_id  = var.resource_group_id
  depends_on = [azapi_resource.custom_table]

  body = {
    properties = {
      dataCollectionEndpointId = azurerm_monitor_data_collection_endpoint.main.id

      # ADDED: This is the missing piece that caused your Custom Log InvalidPayload!
      streamDeclarations = {
        "Custom-ApplicationLogs" = {
          columns = [
            { name = "TimeGenerated", type = "datetime" },
            { name = "RawData", type = "string" }
          ]
        }
      }

      dataSources = {
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
          transformKql = "source | extend Level = tostring(split(RawData, ' ')[0]) | where Level == 'Error' or Level == 'Critical'"
          outputStream = "Custom-ApplicationLogs_CL"
        }
      ]
    }
  }

  tags = var.tags
}

resource "azapi_resource" "custom_table" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2022-10-01"
  name      = "ApplicationLogs_CL"
  parent_id = azurerm_log_analytics_workspace.main.id

  body = {
    properties = {
      schema = {
        name = "ApplicationLogs_CL"
        columns = [
          { name = "TimeGenerated", type = "datetime" },
          { name = "RawData", type = "string" },
          { name = "Level", type = "string" }
        ]
      }
      retentionInDays = 30
    }
  }
}