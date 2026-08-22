# Hub-and-spoke architecture lab
# A spoke VNet's outbound traffic is forced through a centrally-managed
# Azure Firewall sitting in a hub VNet, via VNet Peering and a
# User-Defined Route - rather than each application team building and
# reviewing its own separate outbound security controls.

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

resource "azurerm_resource_group" "lab" {
  name     = "lab-hub-spoke-rg"
  location = "UK South"
}

# --- Hub VNet ---

resource "azurerm_virtual_network" "hub" {
  name                = "hub-vnet"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = ["10.1.0.0/16"]
}

# Exact name required - Azure's firewall deployment automation looks
# specifically for this subnet name to know where to place the firewall.
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.1.0.0/24"]
}

# Required specifically for the Basic SKU - keeps the firewall's own
# management traffic separate from the customer traffic it inspects.
# Discovered as a real deployment error, not anticipated in advance.
resource "azurerm_subnet" "firewall_management" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_public_ip" "firewall" {
  name                = "lab-firewall-pip"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  allocation_method    = "Static"
  sku                   = "Standard"
}

resource "azurerm_public_ip" "firewall_management" {
  name                = "lab-firewall-mgmt-pip"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  allocation_method    = "Static"
  sku                   = "Standard"
}

resource "azurerm_firewall_policy" "lab" {
  name                = "lab-firewall-policy"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  sku                   = "Basic"
}

resource "azurerm_firewall" "lab" {
  name                = "lab-firewall"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic" # cheapest tier - Azure Firewall has no free tier at all
  firewall_policy_id = azurerm_firewall_policy.lab.id

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  management_ip_configuration {
    name                 = "fw-mgmt-ipconfig"
    subnet_id            = azurerm_subnet.firewall_management.id
    public_ip_address_id = azurerm_public_ip.firewall_management.id
  }
}

# --- Spoke VNet ---

resource "azurerm_virtual_network" "spoke" {
  name                = "spoke-vnet"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = ["10.2.0.0/16"]
}

resource "azurerm_subnet" "workload" {
  name                 = "workload-subnet"
  resource_group_name = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.2.1.0/24"]
}

# --- Peering (bidirectional - two separate objects, one per VNet,
# since each network's owner independently consents to the relationship) ---

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                       = "hub-to-spoke"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name       = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                       = "spoke-to-hub"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name       = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
}

# --- User-Defined Route: forces the spoke's outbound traffic through
# the firewall, rather than a direct, unfiltered path to the internet ---

resource "azurerm_route_table" "spoke_to_firewall" {
  name                = "spoke-to-firewall-route"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
}

resource "azurerm_route" "default_via_firewall" {
  name                   = "default-via-firewall"
  resource_group_name   = azurerm_resource_group.lab.name
  route_table_name       = azurerm_route_table.spoke_to_firewall.name
  address_prefix         = "0.0.0.0/0" # matches all destinations
  next_hop_type           = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.lab.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "workload" {
  subnet_id      = azurerm_subnet.workload.id
  route_table_id = azurerm_route_table.spoke_to_firewall.id
}

