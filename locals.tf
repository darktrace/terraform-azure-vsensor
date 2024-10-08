locals {
  deployment_id = var.short_id
  vnet_enable   = length(var.vnet_name) == 0
  vnet_name     = local.vnet_enable ? "${local.deployment_id}-vnet" : var.vnet_name
  vnet_rg       = local.vnet_enable ? local.rg : data.azurerm_resource_group.vnet_rg_existing[0]
  vnet_rg_name  = local.vnet_enable ? local.rg.name : var.vnet_rg
  vnet          = local.vnet_enable ? azurerm_virtual_network.vnet_new[0] : data.azurerm_virtual_network.vnet_existing[0]
  vnet_same_rg  = local.vnet_rg_name == local.rg_name # Use names since id's require data resources which can't be used with count.
  # If we are generating a new VNet, we must be generating a new subnet. Otherwise, we may be using or generating a new subnet.
  subnet_enable = local.vnet_enable ? true : length(var.subnet_name) == 0
  subnet        = local.subnet_enable ? azurerm_subnet.vsensor_subnet[0] : data.azurerm_subnet.vsensor_subnet_existing[0]
  vmss_name     = "${local.deployment_id}-vsensor-vmss"
  rg_enable     = length(var.rg_name) == 0
  rg            = local.rg_enable ? azurerm_resource_group.rg[0] : data.azurerm_resource_group.rg_existing[0]
  rg_name       = local.rg_enable ? "${local.deployment_id}-rg" : var.rg_name
  # If user provides a location, use that. If not, use the location of the resource group provided.
  location = length(var.location) > 0 ? var.location : (local.rg.location)

  lb_name                = "${local.deployment_id}-loadbalancer"
  lb_frontend_name       = "${local.lb_name}-frontend"
  lb_frontend_proxy_name = "${local.lb_name}-frontend-proxy"
  lb_direct_enable       = var.private_link_enable ? 0 : 1
  # A DNS zone unique to this deployment (at least at a per subscription level)
  lb_local_dns_zone = "${lower(var.short_id)}-ossensor.private-lb.darktrace.com"
  # A name for the A record within this zone for the LB.
  lb_local_dns_record = "vsensor"
  # Combined to make vsensor.XXXXXX-osensor.private-lb.darktrace.com. This is what actually resolves to the LB.
  lb_local_dns_fqdn = join(".", [local.lb_local_dns_record, local.lb_local_dns_zone])
  # When private link is disabled, the load balancer is only used for registration
  # Therefore, every registration we want a random chance of being assigned a vSensor to communicate directly with.
  # When private link is on, the vSensor does not return it's IP address, as this may be incorrect if accessing via private link.
  # Therefore, all osSensor traffic goes via the load balancer and it must be "sticky" to keep an osSensor connected to a single vSensor.
  lb_distribution_mode = var.private_link_enable ? "SourceIP" : "Default"
  lb_backend_name      = "${local.lb_name}-backend"

  pcaps_storage_enable = var.lifecycle_pcaps_blob_days > 0
  pcaps_name           = lower("${local.deployment_id}-pcaps")
  # Storage Account must be lowercase letters and numbers only.
  pcaps_sa_name = lower(join("", [substr(local.deployment_id, 0, 15), substr(random_uuid.pcap_uuid.result, 0, 4), "pcaps"]))

  data_collection_name = "${local.deployment_id}-datacollect"

  common_tags = {
    deployment_id = local.deployment_id
    deployed_by   = "Darktrace vSensor Terraform Quickstart"
  }
  all_tags = merge(
    local.common_tags,
    var.tags
  )
}
