# Azure Monitor Agent Extension for Windows VMs
resource "azurerm_virtual_machine_extension" "ama_windows" {
  for_each = { for vm in var.windows_vms : vm.name => vm }
  
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = each.value.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  
  settings = jsonencode({
    workspaceId               = var.workspace_customer_id
    azureResourceId           = each.value.id
    stopOnMultipleConnections = false
  })
  
  protected_settings = jsonencode({
    workspaceKey = var.workspace_primary_key
  })
  
  tags = var.tags
}

# Azure Monitor Agent Extension for Linux VMs
resource "azurerm_virtual_machine_extension" "ama_linux" {
  for_each = { for vm in var.linux_vms : vm.name => vm }
  
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = each.value.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  
  settings = jsonencode({
    workspaceId               = var.workspace_customer_id
    azureResourceId           = each.value.id
    stopOnMultipleConnections = false
  })
  
  protected_settings = jsonencode({
    workspaceKey = var.workspace_primary_key
  })
  
  tags = var.tags
}

# Dependency Agent for Service Map (Windows)
resource "azurerm_virtual_machine_extension" "dependency_windows" {
  for_each = var.enable_service_map ? { for vm in var.windows_vms : vm.name => vm } : {}
  
  name                       = "DependencyAgentWindows"
  virtual_machine_id         = each.value.id
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  auto_upgrade_minor_version = true
  
  depends_on = [azurerm_virtual_machine_extension.ama_windows]
  
  tags = var.tags
}

# Dependency Agent for Service Map (Linux)
resource "azurerm_virtual_machine_extension" "dependency_linux" {
  for_each = var.enable_service_map ? { for vm in var.linux_vms : vm.name => vm } : {}
  
  name                       = "DependencyAgentLinux"
  virtual_machine_id         = each.value.id
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentLinux"
  type_handler_version       = "9.10"
  auto_upgrade_minor_version = true
  
  depends_on = [azurerm_virtual_machine_extension.ama_linux]
  
  tags = var.tags
}

# Associate VMs with Data Collection Rule
resource "azurerm_monitor_data_collection_rule_association" "vm_windows" {
  for_each = { for vm in var.windows_vms : vm.name => vm }
  
  name                    = "dcr-association-${each.key}"
  target_resource_id      = each.value.id
  data_collection_rule_id = var.data_collection_rule_id
  description             = "Association for ${each.key}"
}

resource "azurerm_monitor_data_collection_rule_association" "vm_linux" {
  for_each = { for vm in var.linux_vms : vm.name => vm }
  
  name                    = "dcr-association-${each.key}"
  target_resource_id      = each.value.id
  data_collection_rule_id = var.data_collection_rule_id
  description             = "Association for ${each.key}"
}

# VM Scale Set extensions (if using VMSS)
resource "azurerm_virtual_machine_scale_set_extension" "ama_vmss_windows" {
  for_each = { for vmss in var.windows_vmss : vmss.name => vmss }
  
  name                         = "AzureMonitorWindowsAgent"
  virtual_machine_scale_set_id = each.value.id
  publisher                    = "Microsoft.Azure.Monitor"
  type                         = "AzureMonitorWindowsAgent"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true
  automatic_upgrade_enabled    = true
  
  settings = jsonencode({
    workspaceId = var.workspace_customer_id
  })
  
  protected_settings = jsonencode({
    workspaceKey = var.workspace_primary_key
  })
}

resource "azurerm_virtual_machine_scale_set_extension" "ama_vmss_linux" {
  for_each = { for vmss in var.linux_vmss : vmss.name => vmss }
  
  name                         = "AzureMonitorLinuxAgent"
  virtual_machine_scale_set_id = each.value.id
  publisher                    = "Microsoft.Azure.Monitor"
  type                         = "AzureMonitorLinuxAgent"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true
  automatic_upgrade_enabled    = true
  
  settings = jsonencode({
    workspaceId = var.workspace_customer_id
  })
  
  protected_settings = jsonencode({
    workspaceKey = var.workspace_primary_key
  })
}
