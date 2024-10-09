resource "azurerm_subnet" "bastion_subnet" {
  count = var.bastion_enable ? 1 : 0

  name                 = "AzureBastionSubnet"
  resource_group_name  = local.vnet_rg.name
  virtual_network_name = local.vnet.name
  address_prefixes     = [var.bastion_subnet_cidr]
}

resource "azurerm_public_ip" "bastion_public_ip" {
  count = var.bastion_enable ? 1 : 0

  name                = "${local.deployment_id}-bas-pip"
  location            = local.location
  resource_group_name = local.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.all_tags
}

resource "azurerm_bastion_host" "bastion" {
  count = var.bastion_enable ? 1 : 0

  name                = "${local.deployment_id}-bas"
  location            = local.location
  resource_group_name = local.rg.name
  copy_paste_enabled  = true
  file_copy_enabled   = true
  sku                 = "Standard"
  ip_configuration {
    name                 = "IpConf"
    subnet_id            = azurerm_subnet.bastion_subnet[0].id
    public_ip_address_id = azurerm_public_ip.bastion_public_ip[0].id
  }
  ip_connect_enabled = false
  tunneling_enabled  = true

  tags = local.all_tags
}
