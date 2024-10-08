data "azurerm_subscription" "subscription" {}

# If an existing resource group has been provided, get it.
data "azurerm_resource_group" "rg_existing" {
  count = local.rg_enable ? 0 : 1
  name  = var.rg_name
}

# Create a new resource group if none provided.
resource "azurerm_resource_group" "rg" {
  count = local.rg_enable ? 1 : 0
  name  = "${local.deployment_id}-rg"
  # Can't use local.location here as it would be a cycle. If we are creating a resource group, customer must provide the location.
  location = length(var.location) > 0 ? var.location : "Invalid Configuration"
}

data "azurerm_resource_group" "vnet_rg_existing" {
  count = local.vnet_enable ? 0 : 1
  name  = var.vnet_rg
}

check "existing_vnet_with_resource_group" {
  assert {
    condition     = !(length(var.vnet_name) > 0 && var.vnet_rg == null)
    error_message = "You must provide an existing resource group name in vnet_rg when using an existing VNet."
  }
}

check "resource_location" {
  assert {
    condition     = local.vnet_enable ? true : data.azurerm_virtual_network.vnet_existing[0].location == local.location
    error_message = "Existing VNet must be in same location as the new resources."
  }
}

check "route_table_and_nat" {
  assert {
    condition     = !(var.nat_gw_enable && length(var.route_table_name) > 0)
    error_message = "Providing an existing route table and enabling NAT Gateway is likely not a suitable configuration, please confirm."
  }
}

check "no_internet" {
  assert {
    condition     = !(local.vnet_enable && (!var.nat_gw_enable && length(var.route_table_name) == 0))
    error_message = "Internet connectivity is required to install the vSensor package. It does not appear a NAT Gateway or existing route table has been provided to allow this. Please confirm."
  }
}

check "new_vnet_with_existing_subnet" {
  assert {
    condition     = !(length(var.vnet_name) == 0 && length(var.subnet_name) != 0)
    error_message = "This module cannot create a new VNet with an existing subnet. Please either create a new subnet instead or use an existing VNet."
  }
}
check "new_rg_requires_location" {
  assert {
    condition     = !(length(var.location) == 0 && length(var.rg_name) == 0)
    error_message = "A resource location is required to launch the new resources when an existing rg_name is not provided."
  }
}

check "new_vnet_has_cidr" {
  assert {
    condition     = !(length(var.vnet_name) == 0 && var.vnet_cidr == null)
    error_message = "If an existing vnet_name has not been provided, a vnet_cidr must be provided to generate a new VNet."
  }
}
check "new_subnet_has_cidr" {
  assert {
    condition     = !(length(var.subnet_name) == 0 && var.subnet_cidr == null)
    error_message = "If an existing subnet_name has not been provided, a subnet_cidr must be provided to generate a new subnet."
  }
}

check "new_bastion_has_cidr" {
  assert {
    condition     = !(var.bastion_enable == true && var.bastion_subnet_cidr == null)
    error_message = "When bastion_enable is true, a bastion_subnet_cidr must be provided to generate a new subnet for the bastion."
  }
}
