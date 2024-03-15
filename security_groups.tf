resource "azurerm_network_security_group" "vsensors_vmss_nsg" {
  count               = local.subnet_enable ? 1 : 0
  name                = "${local.deployment_id}-vsensors-nsg"
  location            = local.location
  resource_group_name = local.rg.name

  security_rule {
    name                       = "AllowMgmtInPorts22"
    description                = "Allow Inbound traffic to TCP ports 22 from customer selected IPs/Ranges."
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowLoadBalancerHTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "80-81"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowLoadBalancerHTTPS"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "443-444"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowOSSensorHTTPS"
    description                = "Allow HTTPS traffic from osSensors to vSensor and PROXYv2 traffic from Private Link."
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443-444"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowOSSensorHTTP"
    description                = "Allow HTTP traffic from osSensors to vSensor and PROXYv2 traffic from Private Link."
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80-81"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowOutboundHTTP"
    description                = "Allow HTTP traffic from vSensor to packages{-cdn}.darktrace.com/*ubuntu.com"
    priority                   = 1005
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowOutboundHTTPS"
    description                = "Allow HTTPS traffic from vSensor to packages{-cdn}.darktrace.com/*ubuntu.com"
    priority                   = 1006
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "DenyOutboundInternet"
    description                = "Deny rest of internet outbound."
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
  security_rule {
    name                       = "DenyAllIn"
    description                = "Deny all Inbound traffic."
    priority                   = 4095
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  dynamic "security_rule" {
    for_each = var.instance_port != 443 ? [true] : []
    content {
      name                       = "AllowOutboundMasterPort"
      description                = "Allow HTTPS traffic from vSensor to Master on custom port"
      priority                   = 1004
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = var.instance_port
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
  dynamic "security_rule" {
    for_each = var.bastion_enable ? [true] : []
    content {
      name                       = "AllowAzureBastion"
      description                = "Allow Bastion traffic to vSensor"
      priority                   = 1005
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = var.bastion_subnet_cidr
      destination_address_prefix = "*"
    }
  }

  tags = local.all_tags
}

resource "azurerm_subnet_network_security_group_association" "vsensors_vmss_nsg_asoc" {
  count                     = local.subnet_enable ? 1 : 0
  subnet_id                 = local.subnet.id
  network_security_group_id = azurerm_network_security_group.vsensors_vmss_nsg[0].id
}
