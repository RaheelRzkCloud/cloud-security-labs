# Managed Identity + Key Vault lab
# Recreates the manual portal build as Terraform, reflecting how this
# would actually be deployed under a no-ClickOps policy via a CI/CD pipeline.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "lab" {
  name     = "lab-managed-identity-rg"
  location = "UK South"
}

resource "azurerm_service_plan" "lab" {
  name                = "rio-mi-lab-plan"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_linux_web_app" "rio_mi_lab" {
  name                = "rio-mi-lab"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  service_plan_id     = azurerm_service_plan.lab.id

  site_config {}

  # System-assigned Managed Identity - no credential to store, rotate, or leak
  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "MySecret" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.test_secret.id})"
  }
}

resource "azurerm_key_vault" "lab" {
  name                = "rio-mi-lab-kv"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id

  # Azure RBAC permission model, consistent with least-privilege
  # role assignment used elsewhere in this repo
  enable_rbac_authorization = true
}

resource "azurerm_key_vault_secret" "test_secret" {
  name         = "TestSecret"
  value        = "HelloFromKeyVault123"
  key_vault_id = azurerm_key_vault.lab.id
}

# Least privilege: the App Service's identity can only READ secrets,
# not manage the vault itself
resource "azurerm_role_assignment" "app_kv_access" {
  scope                = azurerm_key_vault.lab.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.rio_mi_lab.identity[0].principal_id
}

