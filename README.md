# Darktrace vSensor Quickstart for Azure

## Introduction

This document intends to describe how to use the provided Terraform module to deploy automatically scaling Darktrace vSensors in Microsoft Azure.

The Darktrace vSensor is a lightweight virtual probe intended for deployment in cloud-based networks or environments where it is not feasible to deploy a physical probe, such as virtualized networks. In an Azure public cloud environment, vSensors can be deployed as an automatic virtual machine scale set that collects packets from osSensor agents deployed on the VMs that are to be monitored. 

In addition to processing and transmitting network traffic, vSensors can ingest and forward syslog-format logs to the Darktrace master instance. VPN and DHCP logs can provide valuable device-tracking enrichment and custom event types derived from ingested log data. This can be used to integrate with a number of third-party tools.

## Architecture

![Darktrace vSensor Architecture Diagram](source/architecture-diagram.png "Architecture")

In brief, the module will perform the following:
* Create a dedicated Resource Group (optional).
* Create a Virtual Network (optional).
* Create a Subnet for the vSensors (optional).
* Create a Subnet and deploy Azure Bastion to allow access to manage the vSensors (optional).
* Create an Azure Storage Account and Blob Container to hold PCAP data for a configurable retention period (optional).
* Spin up the requested number of compatible base OS VMs in the existing VNet as part of a Virtual Machine Scale Set.
* Automatically download and install the Darktrace vSensor.  
**Note**: a valid Darktrace Update Key is required for this. Please contact your Darktrace representative if you do not possess this.
* The vSensors will self-configure. As part of the configuration the vSensor will automatically:
    * Configure automatic OS and Darktrace software updates.
    * Connect and register to the Darktrace master instance (virtual/physical) using the Push Token that has already been generated (on the same master instance).
    * Add the osSensor HMAC Token to allow osSensors to authenticate.
    * Configure the PCAP storage to the shared Blob Container.
* A load balancer is configured with private resolving DNS FQDN to distribute osSensor registrations between available vSensors.
* A Log Analytics workspace is created to house vSensor logs for Azure.
* Deploy an Azure Private Link Service for connecting osSensors outside of the vSensor VNet (optional).

### osSensors

In Microsoft Azure, the configuration and maintenance of the virtual switches is automated and removed from the user’s control. As a result of this lack of access, a direct SPAN cannot be setup from the virtual switch to the vSensor. 

In this environment, the Darktrace osSensor - a lightweight host-based server agent - is used to send a feed from all monitored VMs directly to the vSensor.

These osSensors can be manually installed quickly and simply. However, for large environments there are a number of tools that can be used to facilitate the deployment of osSensors in bulk, such as Ansible, Terraform, and Run Commands. For an in-depth guide on each of these, please see the relevant documentation.

### VNets

In Microsoft Azure, all VMs are separated into virtual networks (VNets) which are logically separated from each other. A vSensor must be placed in each VNet to ensure total coverage of your Azure environment.

It is possible for VNets to be ‘peered’ and for data to be sent across VNets or via Private Link, thus reducing the number of vSensors needing to be deployed. However, this should be carefully considered before implementing as cross regional data transfer can incur a significant financial cost, as well as potential legal and compliance issues surrounding data residency.

## Pre-deployment Requirements

### Virtual Network

The module can be used to deploy vSensor(s) in an existing Virtual Network (VNet) and subnet, or it can deploy its own network environement. When providing an existing VNet, it must have space for up to 2 Subnets to be created:
* A larger subnet for the number of expected vSensors deployed (`/24` recommended).
* A small subnet for the Azure Bastion: `/26` or larger, see [Azure Docs](https://learn.microsoft.com/en-us/azure/bastion/configuration-settings#subnet) (optional).

If you are providing an existing vSensor subnet, ensure a large enough CIDR range is provided, as above.

If the module is to create the VNet and subnets, ensure your privided CIDR ranges are suitable.

If you already use Azure Bastion in your existing VNet, disable creating a bastion in this module to avoid conflict failure.

### Resource Group
The Resource Group (RG) is where the new resources’ metadata will be stored. The resources will be placed in the new/existing RG of the deployment, which may be separate from the VNet for easier management. Any subnets created will still be created within the existing VNet's RG.

### Network Security Group
The template will create a new Network Security Group (NSG) that permits outbound access to the Darktrace Update Packages CDN and the configured master instance on HTTP/HTTPS. It also allows osSensor inbound connectivity on HTTP/HTTPS.

Lastly, it will enable access for SSH management from (private) IP addresses and/or IP Ranges specified in the 'ssh_cidrs' variable.

### VM Sizes
The VM size should be decided based on the vSensor Requirements as described in the ‘Example Sizings’ in the below link:
https://customerportal.darktrace.com/product-guides/main/vsensor-requirements

Various recommended sizes have been provided below, from small burstable CPU sizes for small levels of traffic to large 32 core sizes for high levels of traffic:

* Standard_B2ms
* Standard_D2_v3
* Standard_D4_v3
* Standard_D8_v3
* Standard_D8s_v5
* Standard_D16s_v5
* Standard_D32s_v5

Note that, vSensor performance will vary by CPU speed and the nature of the traffic - estimated sizings are provided for guidance only.

We recommend you choose instance sizes:
* Large enough that traffic spikes don't require large numbers of machines to be scaled up.
* Small enough that low traffic (i.e. outside business hours) doesn't waste too many compute resources.

The disk size in this template is fixed, since PCAPs are stored via a configurable PCAP retention policy (in days). Note that changing the retention policy will affect deployment costs based on the ongoing amount of traffic ingested.

### Admin User SSH Authentication
vSensors will be configured with the admin username and SSH public key provided only, no password login will be accepted. Ensure you possess and keep the correct private key for later use.

### Darktrace Master Communication
To connect and register the vSensor to the Darktrace master instance (or Cloud Master) the following is required:
* The Darktrace master instance’s FQDN or IP and HTTPS port (typically `443/TCP`).
* The push token (generated on the Darktrace Master System Config page).
* Access to the master instance’s FQDN or IP and port.

### osSensor Connectivity
The template will expect the osSensor HMAC Token to be provided so it can configure it as part of the automated configuration.

When an osSensor is in the same VNet, use the DNS FQDN of the load balancer frontend provided in the module outputs under `os_sensor_vsensor_fqdn`. This DNS entry will remain constant between terraform destroy/modifications as long as the same `short_id` is used, such that osSensors do not need to be reconfigured after initial deployment.

### Azure Private Link

Azure Private Link is also supported to allow osSensors to be connected from across your Azure environment, including on-premise, other regions and other subscriptions. This means you can deploy fewer instances of Darktrace vSensor in large environments for easier management and lower compute costs.

Enabling the `private_link_enable` variable will do the following:
* Create a Azure Private Link Service in the vSensor subnet with TCP Proxy v2 support enabled.
* Create a secondary load balancer frontend such that both local VNet (non-proxy) and Private Link (proxy) osSensors are supported simultaneously.
* Configure vSensors to accept TCP Proxy v2 protocol from the created Private Link service and load balancer health probes (`168.63.129.16/32`, see [Microsoft documentation](https://learn.microsoft.com/en-us/azure/virtual-network/what-is-ip-address-168-63-129-16)) via IP address firewalling.
* Configures all osSensor traffic to travel through the load balancer, rather than taking a direct route after vSensor discovery and registration. PLEASE NOTE: This will also incur extra bandwidth costs for local osSensors.

When using Azure Private Link, osSensors must be configured with the IP address or DNS of the Private Link Endpoint you manually create and connect to the provided Private Link Service, named under deployment output `ossensor_private_link_service_id`.

NOTE: The use of TCP Proxy v2 is required with Private Link Services so that osSensors can be separately identified. Overlapping osSensor IPs are not supported.

NOTE: Private Link Service Network Policies must be disabled before using an existing vSensor subnet when enabling Private Link in this module. See [Microsoft documentation](https://learn.microsoft.com/en-us/azure/private-link/disable-private-link-service-network-policy?tabs=private-link-network-policy-cli)

### Access to the vSensor
The vSensors created will not have public IPs associated. Exposing a vSensor via a public IP carries additional security burden and is not a requirement of push token authentication with the master instance.

It is expected that there is already a solution in place to access the VMs in the VNet via their private IP. If one is not present, the module can install a Azure Bastion Host and subnet to the VNet using the 'bastion_enable' variable. Don't select this option if you already have a Azure Bastion in your VNet.

If there is a virtual firewall on your network, please ensure access is granted to the vSensor to the Darktrace instance FQDN/port or IP/port, as well as to *ubuntu.com, packages.darktrace.com and packages-cdn.darktrace.com on port `80/TCP` and `443/TCP`. The deployed NSG will attempt to configure this access.

### Existing Subnet Deployments

If you are deploying into an existing subnet, you must allow internet access on ports 443 and 80 to allow vSensor installation and updates from packages.darktrace.com and packages-cdn.darktrace.com (and to your master, if applicable). See `security_groups.tf` for the required access. If this access is not configured before deployment of this module, the "DarktraceVSensorInstaller" VM Extension will fail to install.

NOTE: when deploying with PCAP storage, you must include `Microsoft.Storage` in your subnet resource `service_endpoints` parameter and include the module output `pcaps_service_endpoint_policy_id` in the `service_endpoint_policy_ids` parameter BEFORE deploying this module. This allows PCAP storage requests to go via a private endpoint to Azure Storage for further increased security, public access is disabled.

You may need to include references to your existing Resource Group and VNet in the module as a `depends_on`, see `Deploy Darktrace vSensor into an existing VNet / subnet` below.

## Usage

Please note an explicit provider configuration is required to apply `storage_use_azuread = true` configuration to the module, see below.

It is also recommended the Terraform state is encrypted as it will contain the sensitive keys provided in the module variables. See [Sensitive Data in State](https://developer.hashicorp.com/terraform/language/state/sensitive-data).

### Deploy Darktrace vSensor into a new VNet

This example shows a fully featured module in a new resource group, with PCAP storage, Azure Bastion and Private Link deployed into a new VNet with NAT Gateway for internet access.

```
provider "azurerm" {
  alias = "azurerm_darktrace"
  features {
  }
  # Use AzureAD for storage rather than shared keys.
  # We have disabled shared keys. Some features we are not using require this default false due to incomplete API.
  storage_use_azuread = true # https://github.com/hashicorp/terraform-provider-azurerm/issues/17341
}

module "vsensors" {
  source = "git::https://github.com/darktrace/terraform-azure-vsensor?ref=<version>"

  location = "West Europe"
  short_id = "example-deployment"

  zones = [1, 2]

  vnet_cidr           = "10.0.0.0/16"
  subnet_cidr         = "10.0.1.0/24"
  nat_gw_enable       = true
  bastion_enable      = true
  bastion_subnet_cidr = "10.0.160.0/24"

  terraform_cidrs = ["1.2.3.4"]

  instance_size = "Standard_D2_v3"
  min_size      = 1
  max_size      = 5

  ssh_admin_username = "darktrace"
  ssh_pubkey         = "XXXXXXXXXXX"

  update_key = "XXXXXXXXXX:YYYYYYYYY"

  instance_host_name = "example.cloud.darktrace.com"
  push_token         = "AAAAAAAAAAA:BBBBBBBBBBB"

  os_sensor_hmac_token = "CCCCCCCCCCCCCCC"

  lifecycle_pcaps_blob_days = 14

  private_link_enable = true

  tags = {
    "example-name" : "example-value"
  }

  providers = {
    azurerm = azurerm.azurerm_darktrace
  }

}
```

### Deploy Darktrace vSensor into an existing VNet / subnet

This example shows a more limited deployment into an existing resource group, existing VNet with an existing route table for internet access. No PCAP storage.

Note the `depends_on` used for Resource Group and VNet. This may be required when the resources are created within the same terraform codebase and do not exist before deploying the module.

This extra configuration allows the RG and VNet to be created first.

```
provider "azurerm" {
  alias = "azurerm_darktrace"
  features {
  }
  # Use AzureAD for storage rather than shared keys.
  # We have disabled shared keys. Some features we are not using require this default false due to incomplete API.
  storage_use_azuread = true # https://github.com/hashicorp/terraform-provider-azurerm/issues/17341
}

module "vsensors" {
  source = "git::https://github.com/darktrace/terraform-azure-vsensor?ref=<version>"

  location = "West Europe"
  short_id = "example-deployment"

  rg_name = "existing-resource-group"

  vnet_name   = "existing-vnet-name"
  vnet_rg     = "existing-resource-group"
  subnet_name = "existing-subnet"

  nat_gw_enable    = false
  route_table_name = "existing-route-table"
  route_table_rg   = "existing-route-table-resource-group"

  ssh_cidrs       = ["10.100.1.5"]
  terraform_cidrs = ["1.2.3.4"]

  instance_size = "Standard_D2_v3"
  min_size      = 1
  max_size      = 5

  ssh_admin_username = "darktrace"
  ssh_pubkey         = "XXXXXXXXXXX"

  update_key = "XXXXXXXXXX:YYYYYYYYY"

  instance_host_name = "example.cloud.darktrace.com"
  instance_port      = 443
  instance_proxy     = "http://proxy.local:3128"
  push_token         = "AAAAAAAAAAA:BBBBBBBBBBB"

  os_sensor_hmac_token = "CCCCCCCCCCCCCCC"

  lifecycle_pcaps_blob_days = 0

  providers = {
    azurerm = azurerm.azurerm_darktrace
  }

  #depends_on = [ azurerm_resource_group.rg_existing, azurerm_virtual_network.vnet_existing ]
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.85 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.5 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_bastion_host.bastion](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/bastion_host) | resource |
| [azurerm_lb.lb](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb) | resource |
| [azurerm_lb_backend_address_pool.lb_backend](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_backend_address_pool) | resource |
| [azurerm_lb_probe.lb_probe_http](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_probe) | resource |
| [azurerm_lb_probe.lb_probe_http_proxy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_probe) | resource |
| [azurerm_lb_probe.lb_probe_https](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_probe) | resource |
| [azurerm_lb_probe.lb_probe_https_proxy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_probe) | resource |
| [azurerm_lb_rule.lb_rule_http](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_rule) | resource |
| [azurerm_lb_rule.lb_rule_http_proxy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_rule) | resource |
| [azurerm_lb_rule.lb_rule_https](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_rule) | resource |
| [azurerm_lb_rule.lb_rule_https_proxy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_rule) | resource |
| [azurerm_linux_virtual_machine_scale_set.vsensor_vmss](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set) | resource |
| [azurerm_log_analytics_workspace.vsensor_logs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |
| [azurerm_monitor_autoscale_setting.vmss_autoscale](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_autoscale_setting) | resource |
| [azurerm_monitor_data_collection_rule.vsensor_data_collection](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_data_collection_rule) | resource |
| [azurerm_monitor_data_collection_rule_association.vsensor_data_collection_assoc](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_data_collection_rule_association) | resource |
| [azurerm_nat_gateway.natgw](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway) | resource |
| [azurerm_nat_gateway_public_ip_association.natgw_public_ip_association](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway_public_ip_association) | resource |
| [azurerm_network_security_group.vsensors_vmss_nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_private_dns_a_record.ossensor_lb_dns_record](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_a_record) | resource |
| [azurerm_private_dns_zone.ossensor_lb_zone](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.ossensor_lb_vnet_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_link_service.ossensor_private_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_link_service) | resource |
| [azurerm_public_ip.bastion_public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_public_ip.natgw_public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.pcaps_role_blob_contrib](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.pcaps_role_storage_contrib](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.pcaps_storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_account_network_rules.pcaps_storage_network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account_network_rules) | resource |
| [azurerm_storage_container.pcaps_storage_container](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azurerm_storage_management_policy.pcaps_storage_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_management_policy) | resource |
| [azurerm_subnet.bastion_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.vsensor_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_nat_gateway_association.vsensor_subnet_natgw](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_nat_gateway_association) | resource |
| [azurerm_subnet_network_security_group_association.vsensors_vmss_nsg_asoc](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_subnet_route_table_association.vsensor_existing_route_table_assoc](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) | resource |
| [azurerm_subnet_service_endpoint_storage_policy.pcaps_service_endpoint_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_service_endpoint_storage_policy) | resource |
| [azurerm_virtual_machine_scale_set_extension.azure_monitor_extension](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_scale_set_extension) | resource |
| [azurerm_virtual_machine_scale_set_extension.vsensor_install](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_scale_set_extension) | resource |
| [azurerm_virtual_network.vnet_new](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [random_uuid.pcap_uuid](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |
| [azurerm_resource_group.rg_existing](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_resource_group.vnet_rg_existing](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_route_table.vsensor_existing_route_table](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/route_table) | data source |
| [azurerm_subnet.vsensor_subnet_existing](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |
| [azurerm_subscription.subscription](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |
| [azurerm_virtual_network.vnet_existing](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bastion_enable"></a> [bastion\_enable](#input\_bastion\_enable) | Deploy a Azure Bastion host to access your vSensor deployment. If 'false' is selected, configure your ssh access manually after deployment. | `bool` | `false` | no |
| <a name="input_bastion_subnet_cidr"></a> [bastion\_subnet\_cidr](#input\_bastion\_subnet\_cidr) | CIDR IP range of the private subnet the Azure Bastion will be deployed in (if deployed). This must be an unused range within the supplied vNet. E.g. 10.0.160.0/24. If Bastion Enable is false, this value will be ignored. | `string` | `null` | no |
| <a name="input_instance_host_name"></a> [instance\_host\_name](#input\_instance\_host\_name) | The FQDN or IP of the Darktrace master instance (virtual/physical). | `string` | n/a | yes |
| <a name="input_instance_port"></a> [instance\_port](#input\_instance\_port) | Connection port between vSensor and the Darktrace Master instance. | `number` | `443` | no |
| <a name="input_instance_proxy"></a> [instance\_proxy](#input\_instance\_proxy) | (Optional) A proxy that should be specified in the format http://user:pass@hostname:port. | `string` | `""` | no |
| <a name="input_instance_size"></a> [instance\_size](#input\_instance\_size) | The VM size. Check the Darktrace customer portal for more information about the vSensor Virtual Hardware requirements. | `string` | `"Standard_D2_v3"` | no |
| <a name="input_lifecycle_pcaps_blob_days"></a> [lifecycle\_pcaps\_blob\_days](#input\_lifecycle\_pcaps\_blob\_days) | Number of days to retain captured packets in Azure Blob Storage. Longer retention will increase storage costs. Set to 0 to disable PCAP storage. | `number` | `7` | no |
| <a name="input_location"></a> [location](#input\_location) | Location for all resources. Leave blank for Resource Group location. | `string` | `""` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | The maximum number of vSensors to be deployed by auto-scaling during high traffic. | `number` | `5` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | The minimum number of vSensors to auto-scale down to. | `number` | `2` | no |
| <a name="input_nat_gw_enable"></a> [nat\_gw\_enable](#input\_nat\_gw\_enable) | Deploy a NAT Gateway in the Virtual Network. If using an existing VNet and are using other firewall configurations, false may be required. | `bool` | `true` | no |
| <a name="input_os_sensor_hmac_token"></a> [os\_sensor\_hmac\_token](#input\_os\_sensor\_hmac\_token) | The hash-based message authentication code (HMAC) token to authenticate osSensors with vSensor. | `string` | n/a | yes |
| <a name="input_private_link_enable"></a> [private\_link\_enable](#input\_private\_link\_enable) | If `true` will create a private link service to attach osSensors from other networks. | `bool` | `false` | no |
| <a name="input_push_token"></a> [push\_token](#input\_push\_token) | Push token to authenticate with the appliance. Should be generated on the Darktrace master instance."<br>  For more information, see the Darktrace Customer Portal (https://customerportal.darktrace.com/login)." | `string` | n/a | yes |
| <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name) | Name of an existing resource group to deploy the quickstart into. Leave blank to let the quickstart create one. | `string` | `""` | no |
| <a name="input_route_table_name"></a> [route\_table\_name](#input\_route\_table\_name) | If not deploying a NAT Gateway, you may need to provide an existing route table to attach to the new deployed vSensor subnet to allow internet routing. | `string` | `""` | no |
| <a name="input_route_table_rg"></a> [route\_table\_rg](#input\_route\_table\_rg) | The Resource Group the existing Route Table (if provided) is deployed in. Default is same resource group as the VNet. | `string` | `""` | no |
| <a name="input_short_id"></a> [short\_id](#input\_short\_id) | A short (upto 20 character alphanumeric) string to prefix resource names by (where available). | `string` | n/a | yes |
| <a name="input_ssh_admin_username"></a> [ssh\_admin\_username](#input\_ssh\_admin\_username) | Administrator username to be created when the vSensor is spun up. | `string` | `"darktrace"` | no |
| <a name="input_ssh_cidrs"></a> [ssh\_cidrs](#input\_ssh\_cidrs) | Provide a private address range using CIDR notation (e.g. 10.1.0.0/24), or an IP address (e.g. 192.168.99.21) for Management access via ssh (port 22/TCP). | `list(any)` | `null` | no |
| <a name="input_ssh_pubkey"></a> [ssh\_pubkey](#input\_ssh\_pubkey) | Public key for the admin username to ssh to the vSensors. Note that password authentication over ssh for newly created VMs is disabled | `string` | n/a | yes |
| <a name="input_subnet_cidr"></a> [subnet\_cidr](#input\_subnet\_cidr) | CIDR IP range of the new private subnet the vSensors will be deployed in. This is ignored if an existing subnet\_name is provided. This must be an unused range within the supplied VNet. E.g. 10.0.0.0/24 | `string` | `null` | no |
| <a name="input_subnet_name"></a> [subnet\_name](#input\_subnet\_name) | Existing Subnet name (within existing provided vnet\_name) that the vSensors should be launched into. Must have 'Microsoft.Storage' Service Endpoint configured. | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all compatible resources. The template will also add tags for the deployment prefix. | `map(string)` | `{}` | no |
| <a name="input_terraform_cidrs"></a> [terraform\_cidrs](#input\_terraform\_cidrs) | Allowed Public CIDR blocks where terraform will execute from. This is required to apply access rules for PCAP storage, whilst also allowing terraform to manage resources. This is due to a limitation with the Azure provider/API. | `list(any)` | n/a | yes |
| <a name="input_update_key"></a> [update\_key](#input\_update\_key) | Darktrace Update Key needed to install the vSensor package. Contact your Darktrace representative for more information. | `string` | n/a | yes |
| <a name="input_vnet_cidr"></a> [vnet\_cidr](#input\_vnet\_cidr) | The IPv4 CIDR block for deploying a new VNet. This is ignored if an existing vnet\_name is provided. Default 10.0.0.0/16. | `string` | `null` | no |
| <a name="input_vnet_name"></a> [vnet\_name](#input\_vnet\_name) | Name of the existing Virtual Network to be monitored, should be in the same location as this deployment/resource group. Leave blank to deploy a new VNet. | `string` | `""` | no |
| <a name="input_vnet_rg"></a> [vnet\_rg](#input\_vnet\_rg) | The Resource Group the existing Virtual Network is deployed in. Default is same RG. | `string` | `null` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | Availability Zone numbers to deploy the vSensors. At least two availablity zones are required. Defaults to random assignment. | `list(number)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_nat_external_ip"></a> [nat\_external\_ip](#output\_nat\_external\_ip) | IP Address of the external NAT Gateway. Permit this IP to access the Darktrace master instance. Darktrace Cloud instances are already configured for this access. |
| <a name="output_nat_external_ip_id"></a> [nat\_external\_ip\_id](#output\_nat\_external\_ip\_id) | ID of the external NAT Gateway. |
| <a name="output_os_sensor_vsensor_cidr"></a> [os\_sensor\_vsensor\_cidr](#output\_os\_sensor\_vsensor\_cidr) | IP address CIDR of the vSensors to allow from osSensors via any relevent firewall rules. |
| <a name="output_os_sensor_vsensor_fqdn"></a> [os\_sensor\_vsensor\_fqdn](#output\_os\_sensor\_vsensor\_fqdn) | Private DNS address of the vSensor Load Balancer which should be configured on the osSensor. |
| <a name="output_ossensor_private_link_service_id"></a> [ossensor\_private\_link\_service\_id](#output\_ossensor\_private\_link\_service\_id) | ID of the Private Link Service (if created) to allow osSensors from other networks. |
| <a name="output_pcaps_service_endpoint_policy_id"></a> [pcaps\_service\_endpoint\_policy\_id](#output\_pcaps\_service\_endpoint\_policy\_id) | Service endpoint policy for the created PCAPs storage account. Attach this to an existing subnet terraform resource with `service_endpoint_policy_ids` |
| <a name="output_pcaps_storage_account_id"></a> [pcaps\_storage\_account\_id](#output\_pcaps\_storage\_account\_id) | ID of the Storage account (if created) to store PCAP data for later retrieval from the Threat Visualizer UI. |
| <a name="output_pcaps_storage_account_name"></a> [pcaps\_storage\_account\_name](#output\_pcaps\_storage\_account\_name) | Name of the Storage account (if created) to store PCAP data for later retrieval from the Threat Visualizer UI. |
| <a name="output_pcaps_storage_container_id"></a> [pcaps\_storage\_container\_id](#output\_pcaps\_storage\_container\_id) | ID of the Storage Blob Container (if created) to store PCAP data for later retrieval from the Threat Visualizer UI. |
| <a name="output_pcaps_storage_container_name"></a> [pcaps\_storage\_container\_name](#output\_pcaps\_storage\_container\_name) | Name of the Storage Blob Container (if created) to store PCAP data for later retrieval from the Threat Visualizer UI. |
| <a name="output_rg_location"></a> [rg\_location](#output\_rg\_location) | Resource Group Location of the provided or new resource group for the created resources. |
| <a name="output_rg_name"></a> [rg\_name](#output\_rg\_name) | Resource Group Name of the provided or new resource group for the created resources. |
| <a name="output_vnet_bastion_id"></a> [vnet\_bastion\_id](#output\_vnet\_bastion\_id) | Resource ID of the Azure Bastion, if created. |
| <a name="output_vnet_bastion_name"></a> [vnet\_bastion\_name](#output\_vnet\_bastion\_name) | Name of the Azure Bastion, if created. |
| <a name="output_vnet_bastion_subnet_id"></a> [vnet\_bastion\_subnet\_id](#output\_vnet\_bastion\_subnet\_id) | Subnet ID of the Azure Bastion, if created. |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | Resource ID of the deployment Virtual Network either created by or passed into this module. |
| <a name="output_vnet_name"></a> [vnet\_name](#output\_vnet\_name) | Name of the deployment Virtual Network either created by or passed into this module. |
| <a name="output_vnet_vsensor_subnet_id"></a> [vnet\_vsensor\_subnet\_id](#output\_vnet\_vsensor\_subnet\_id) | Resource ID of the deployment vSensor Subnet either created by or passed into this module. |
| <a name="output_vnet_vsensor_subnet_name"></a> [vnet\_vsensor\_subnet\_name](#output\_vnet\_vsensor\_subnet\_name) | Name of the deployment vSensor Subnet either created by or passed into this module. |
