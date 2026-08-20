# Landing zone governance lab
# Management group + inherited Azure Policy, preventing publicly accessible
# storage accounts from being created anywhere underneath it - regardless
# of which subscription is nested inside, present or future.
#
# Two policies are assigned, targeting two genuinely different risks:
# - anonymous blob access (data readable without authentication)
# - public network access (the account reachable from the internet at all)
# These are NOT the same setting - see README for how discovering that
# distinction was the actual core lesson of this lab.

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

resource "azurerm_management_group" "lab_landing_zone" {
  display_name = "Lab Landing Zone"
}

resource "azurerm_management_group_subscription_association" "lab_sub" {
  management_group_id = azurerm_management_group.lab_landing_zone.id
  subscription_id      = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

# Policy 1: blocks storage accounts allowing anonymous blob access
# (data readable with no authentication at all)
data "azurerm_policy_definition" "storage_public_access" {
  display_name = "Configure your Storage account public access to be disallowed"
}

resource "azurerm_management_group_policy_assignment" "block_anonymous_blob" {
  name                 = "block-anonymous-blob-access"
  management_group_id = azurerm_management_group.lab_landing_zone.id
  policy_definition_id = data.azurerm_policy_definition.storage_public_access.id

  parameters = jsonencode({
    effect = {
      value = "Deny"
    }
  })
}

# Policy 2: blocks storage accounts from being reachable over the public
# internet at all - a distinct, broader control from anonymous blob access.
# This is the policy that ultimately proved the lab worked - see README.
data "azurerm_policy_definition" "public_network_access" {
  display_name = "Storage accounts should disable public network access"
}

resource "azurerm_management_group_policy_assignment" "block_public_network" {
  name                 = "block-public-network-access"
  management_group_id = azurerm_management_group.lab_landing_zone.id
  policy_definition_id = data.azurerm_policy_definition.public_network_access.id

  parameters = jsonencode({
    effect = {
      value = "Deny"
    }
  })
}

