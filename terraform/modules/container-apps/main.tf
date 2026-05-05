# Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                       = var.environment_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.log_analytics_workspace_id

  infrastructure_subnet_id       = var.subnet_id
  internal_load_balancer_enabled = var.internal_load_balancer_enabled

  tags = var.tags
}

# Container Apps
resource "azurerm_container_app" "apps" {
  for_each = var.apps

  name                         = each.value.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  template {
    container {
      name   = each.value.name
      image  = each.value.image
      cpu    = each.value.cpu
      memory = each.value.memory

      dynamic "env" {
        for_each = each.value.env

        content {
          name        = env.value.name
          value       = lookup(env.value, "value", null)
          secret_name = lookup(env.value, "secret_name", null)
        }
      }
    }

    min_replicas = each.value.min_replicas
    max_replicas = each.value.max_replicas
  }

  dynamic "secret" {
    for_each = each.value.secrets

    content {
      name  = secret.value.name
      value = secret.value.value
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = var.tags
}
