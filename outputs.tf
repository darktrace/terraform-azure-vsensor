output "rg_name" {
  value       = local.rg.name
  description = "Resource Group Name of the provided or new resource group for the created resources."
}

output "rg_location" {
  value       = local.location
  description = "Resource Group Location of the provided or new resource group for the created resources."
}

output "vnet_id" {
  value       = local.vnet.id
  description = "Resource ID of the deployment Virtual Network either created by or passed into this module."
}

output "vnet_name" {
  value       = local.vnet.name
  description = "Name of the deployment Virtual Network either created by or passed into this module."
}

output "vnet_vsensor_subnet_id" {
  value       = local.subnet.id
  description = "Resource ID of the deployment vSensor Subnet either created by or passed into this module."
}


output "vnet_vsensor_subnet_name" {
  value       = local.subnet.name
  description = "Name of the deployment vSensor Subnet either created by or passed into this module."
}


output "vnet_bastion_id" {
  value       = var.bastion_enable ? azurerm_bastion_host.bastion[0].id : null
  description = "Resource ID of the Azure Bastion, if created."
}

output "vnet_bastion_name" {
  value       = var.bastion_enable ? azurerm_bastion_host.bastion[0].name : null
  description = "Name of the Azure Bastion, if created."
}

output "vnet_bastion_subnet_id" {
  value       = var.bastion_enable ? azurerm_subnet.bastion_subnet[0].id : null
  description = "Subnet ID of the Azure Bastion, if created."
}

output "os_sensor_vsensor_fqdn" {
  value       = local.lb_local_dns_fqdn
  description = "Private DNS address of the vSensor Load Balancer which should be configured on the osSensor."
}

output "os_sensor_vsensor_cidr" {
  value       = local.subnet.address_prefixes[0]
  description = "IP address CIDR of the vSensors to allow from osSensors via any relevent firewall rules."
}

output "ossensor_private_link_service_id" {
  value       = var.private_link_enable ? azurerm_private_link_service.ossensor_private_link[0].id : null
  description = "ID of the Private Link Service (if created) to allow osSensors from other networks."
}

output "nat_external_ip" {
  value       = var.nat_gw_enable ? azurerm_public_ip.natgw_public_ip[0].ip_address : null
  description = "IP Address of the external NAT Gateway. Permit this IP to access the Darktrace master instance. Darktrace Cloud instances are already configured for this access."
}

output "nat_external_ip_id" {
  value       = var.nat_gw_enable ? azurerm_public_ip.natgw_public_ip[0].id : null
  description = "ID of the external NAT Gateway. "
}



output "pcaps_storage_account_name" {
  value       = local.pcaps_storage_enable ? azurerm_storage_account.pcaps_storage_account[0].name : null
  description = "Name of the Storage account (if created) to store PCAP data for later retrieval from the Threat Visualizer UI."
}

output "pcaps_storage_account_id" {
  value       = local.pcaps_storage_enable ? azurerm_storage_account.pcaps_storage_account[0].id : null
  description = "ID of the Storage account (if created) to store PCAP data for later retrieval from the Threat Visualizer UI."
}

output "pcaps_storage_container_name" {
  value       = local.pcaps_storage_enable ? azurerm_storage_container.pcaps_storage_container[0].name : null
  description = "Name of the Storage Blob Container (if created) to store PCAP data for later retrieval from the Threat Visualizer UI."
}

output "pcaps_storage_container_id" {
  value       = local.pcaps_storage_enable ? azurerm_storage_container.pcaps_storage_container[0].id : null
  description = "ID of the Storage Blob Container (if created) to store PCAP data for later retrieval from the Threat Visualizer UI."
}

output "pcaps_service_endpoint_policy_id" {
  value       = local.pcaps_storage_enable ? azurerm_subnet_service_endpoint_storage_policy.pcaps_service_endpoint_policy[0].id : null
  description = "Service endpoint policy for the created PCAPs storage account. Attach this to an existing subnet terraform resource with `service_endpoint_policy_ids`"
}
