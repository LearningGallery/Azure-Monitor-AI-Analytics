terraform {
  required_version = ">= 1.12.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
  
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatesasg001"  # Must be globally unique
    container_name       = "tfstate"
    key                  = "log-analytics-ai.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
  
  skip_provider_registration = false
}

provider "azapi" {
}

