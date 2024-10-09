resource "azurerm_private_link_service" "ossensor_private_link" {
  count = var.private_link_enable ? 1 : 0

  name                = "${local.deployment_id}-pl"
  location            = local.location
  resource_group_name = local.rg.name
  nat_ip_configuration {
    name                       = "vsensor-subnet"
    subnet_id                  = local.subnet.id
    primary                    = true
    private_ip_address_version = "IPv4"
  }
  load_balancer_frontend_ip_configuration_ids = [azurerm_lb.lb.frontend_ip_configuration[1].id]
  enable_proxy_protocol                       = true
  tags                                        = local.all_tags
}
