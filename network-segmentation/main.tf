# Network segmentation lab
# VNet with two subnets, an NSG restricting the database subnet to only
# accept SQL traffic from the web subnet, and Azure SQL with public access
# disabled, reachable only via a Private Endpoint inside the database subnet.

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
  name     = "lab-networking-rg"
  location = "UK South"
}

resource "azurerm_virtual_network" "lab" {
  name                = "lab-vnet"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "web" {
  name                 = "web-subnet"
  resource_group_name = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "database" {
  name                 = "database-subnet"
  resource_group_name = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.0.2.0/24"]

  # Ensures NSG rules actually apply to Private Endpoint traffic in this
  # subnet - without this, NSG rules are bypassed for Private Endpoints by
  # default. Discovered as a real gotcha during the manual build.
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_network_security_group" "database" {
  name                = "database-subnet-nsg"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
}

resource "azurerm_network_security_rule" "allow_web_subnet_sql" {
  name                        = "Allow-Web-Subnet-SQL-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = azurerm_subnet.web.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.database.name
  # No explicit deny rule needed - Azure's default deny-all inbound rule
  # (lowest priority, always present) blocks everything not explicitly
  # matched above this one.
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

resource "azurerm_mssql_server" "lab" {
  name                         = "lab-sql-server-rio"
  resource_group_name         = azurerm_resource_group.lab.name
  location                     = "Australia East" # region availability constraint - see README
  version                       = "12.0"

  # Entra-only authentication - no standing SQL username/password credential,
  # consistent with the Managed Identity principle from the first lab in
  # this repo.
  azuread_administrator {
    login_username = "raheelrazzak91@gmail.com"
    object_id       = data.azurerm_client_config.current.object_id
  }

  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "lab" {
  name        = "lab-sql-db"
  server_id   = azurerm_mssql_server.lab.id
  sku_name    = "GP_S_Gen5_2" # General Purpose Serverless - free tier eligible
}

resource "azurerm_private_endpoint" "sql" {
  name                = "lab-sql-private-endpoint"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.database.id

  private_service_connection {
    name                           = "sql-privateserviceconnection"
    private_connection_resource_id = azurerm_mssql_server.lab.id
    subresource_names               = ["sqlServer"]
    is_manual_connection             = false
  }
}

