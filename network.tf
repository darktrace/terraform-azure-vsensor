resource "azurerm_virtual_network" "vnet_new" {
  count = local.vnet_enable ? 1 : 0

  name                = local.vnet_name
  location            = local.vnet_rg.location
  resource_group_name = local.vnet_rg.name
  address_space       = [var.vnet_cidr]

  tags = local.all_tags
}

data "azurerm_virtual_network" "vnet_existing" {
  count               = local.vnet_enable ? 0 : 1
  name                = local.vnet_name
  resource_group_name = local.vnet_rg.name
}

resource "azurerm_public_ip" "natgw_public_ip" {
  count               = var.nat_gw_enable ? 1 : 0
  name                = "${local.deployment_id}-natgw-public-ip"
  location            = local.location
  resource_group_name = local.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.all_tags
}

resource "azurerm_nat_gateway" "natgw" {
  count                   = var.nat_gw_enable ? 1 : 0
  name                    = "${local.deployment_id}-natgw"
  location                = local.location
  resource_group_name     = local.rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
  tags                    = local.all_tags
}

resource "azurerm_nat_gateway_public_ip_association" "natgw_public_ip_association" {
  count                = var.nat_gw_enable ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.natgw[0].id
  public_ip_address_id = azurerm_public_ip.natgw_public_ip[0].id
}

resource "azurerm_subnet" "vsensor_subnet" {
  count                                         = local.subnet_enable ? 1 : 0
  name                                          = "${local.deployment_id}-vsensor-subnet"
  resource_group_name                           = local.vnet_rg.name
  virtual_network_name                          = local.vnet.name
  address_prefixes                              = [var.subnet_cidr]
  private_link_service_network_policies_enabled = false
  service_endpoints                             = local.pcaps_storage_enable ? ["Microsoft.Storage"] : []
  service_endpoint_policy_ids                   = local.pcaps_storage_enable ? [azurerm_subnet_service_endpoint_storage_policy.pcaps_service_endpoint_policy[0].id] : null
}

data "azurerm_subnet" "vsensor_subnet_existing" {
  count                = local.subnet_enable ? 0 : 1
  virtual_network_name = local.vnet_name
  resource_group_name  = local.vnet_rg.name
  name                 = var.subnet_name
}

resource "azurerm_subnet_nat_gateway_association" "vsensor_subnet_natgw" {
  count          = var.nat_gw_enable ? 1 : 0
  subnet_id      = local.subnet.id
  nat_gateway_id = azurerm_nat_gateway.natgw[0].id
}

data "azurerm_route_table" "vsensor_existing_route_table" {
  count               = length(var.route_table_name) > 0 ? 1 : 0
  name                = var.route_table_name
  resource_group_name = length(var.route_table_rg) > 0 ? var.route_table_rg : local.vnet_rg.name
}


resource "azurerm_subnet_route_table_association" "vsensor_existing_route_table_assoc" {
  count          = length(var.route_table_name) > 0 ? 1 : 0
  subnet_id      = local.subnet.id
  route_table_id = data.azurerm_route_table.vsensor_existing_route_table[0].id
}
