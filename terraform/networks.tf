resource "azurerm_virtual_network" "this" {
  name                = "${azurerm_resource_group.this.name}"
  resource_group_name = azurerm_resource_group.this.name

  location      = azurerm_resource_group.this.location
  address_space = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "aks_nodes" {
  name                = "aks-nodes"
  resource_group_name = azurerm_resource_group.this.name

  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.0.0/24"]
  service_endpoints = [
    "Microsoft.Sql",
    "Microsoft.Storage",
    "Microsoft.KeyVault",
  ]
}

resource "azurerm_subnet" "app_gateway" {
  name                = "app-gateway"
  resource_group_name = azurerm_resource_group.this.name

  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.1.0/24"]
}
