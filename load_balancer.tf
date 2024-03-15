# Probes
resource "azurerm_lb_probe" "lb_probe_https" {
  name                = "vmss-health-probe-443"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Https"
  port                = 443
  probe_threshold     = 1
  request_path        = "/healthcheck"
  interval_in_seconds = 60
  number_of_probes    = 1
}
resource "azurerm_lb_probe" "lb_probe_http" {
  name                = "vmss-health-probe-80"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Http"
  port                = 80
  probe_threshold     = 1
  request_path        = "/healthcheck"
  interval_in_seconds = 60
  number_of_probes    = 1
}
resource "azurerm_lb_probe" "lb_probe_https_proxy" {
  name                = "vmss-health-probe-444"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Https"
  port                = 444
  probe_threshold     = 1
  request_path        = "/healthcheck"
  interval_in_seconds = 60
  number_of_probes    = 1
}
resource "azurerm_lb_probe" "lb_probe_http_proxy" {
  name                = "vmss-health-probe-81"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Http"
  port                = 81
  probe_threshold     = 1
  request_path        = "/healthcheck"
  interval_in_seconds = 60
  number_of_probes    = 1
}

resource "azurerm_lb" "lb" {
  name                = local.lb_name
  location            = local.location
  resource_group_name = local.rg.name
  frontend_ip_configuration {
    name      = local.lb_frontend_name
    subnet_id = local.subnet.id
    # Must be dynamic such that we don't collide on existing subnet deployments.
    # Azure claim the IP address won't change unless the frontend IP configuration gets replaced,
    # which should trigger the vSensor to be re-installed.
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
  }
  frontend_ip_configuration {
    name                          = local.lb_frontend_proxy_name
    subnet_id                     = local.subnet.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
  }
  sku  = "Standard"
  tags = local.all_tags
}

# Backend pools
resource "azurerm_lb_backend_address_pool" "lb_backend" {
  name            = local.lb_backend_name
  loadbalancer_id = azurerm_lb.lb.id
}

# LB rules
resource "azurerm_lb_rule" "lb_rule_https" {
  name                           = "vSensorHTTPS"
  loadbalancer_id                = azurerm_lb.lb.id
  frontend_ip_configuration_name = local.lb_frontend_name
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend.id]
  probe_id                       = azurerm_lb_probe.lb_probe_https.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
  load_distribution              = local.lb_distribution_mode
}
resource "azurerm_lb_rule" "lb_rule_http" {
  name                           = "vSensorHTTP"
  loadbalancer_id                = azurerm_lb.lb.id
  frontend_ip_configuration_name = local.lb_frontend_name
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend.id]
  probe_id                       = azurerm_lb_probe.lb_probe_http.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
  load_distribution              = local.lb_distribution_mode
}

resource "azurerm_lb_rule" "lb_rule_https_proxy" {
  name                           = "vSensorHTTPSPROXY"
  loadbalancer_id                = azurerm_lb.lb.id
  frontend_ip_configuration_name = local.lb_frontend_proxy_name
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 444
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend.id]
  probe_id                       = azurerm_lb_probe.lb_probe_https_proxy.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
  load_distribution              = local.lb_distribution_mode
}
resource "azurerm_lb_rule" "lb_rule_http_proxy" {
  name                           = "vSensorHTTPPROXY"
  loadbalancer_id                = azurerm_lb.lb.id
  frontend_ip_configuration_name = local.lb_frontend_proxy_name
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 81
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend.id]
  probe_id                       = azurerm_lb_probe.lb_probe_http_proxy.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
  load_distribution              = local.lb_distribution_mode
}

resource "azurerm_private_dns_zone" "ossensor_lb_zone" {
  name                = local.lb_local_dns_zone
  resource_group_name = local.rg.name
}

resource "azurerm_private_dns_a_record" "ossensor_lb_dns_record" {
  name                = "vsensor"
  resource_group_name = local.rg.name
  zone_name           = azurerm_private_dns_zone.ossensor_lb_zone.name
  ttl                 = 300
  records             = [azurerm_lb.lb.frontend_ip_configuration[0].private_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "ossensor_lb_vnet_link" {
  name                  = "vsensor_load_balancer"
  resource_group_name   = local.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.ossensor_lb_zone.name
  virtual_network_id    = local.vnet.id
}
