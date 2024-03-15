# Used in locals.tf to rename storage account UUID since you can't
# recreate a new storage account with the same name as an old one.
resource "random_uuid" "pcap_uuid" {
}

# Ignore network_rules being missing causing critical, it is separate below
# It needs to be separate due to a cycle with virtual_network_subnet_ids
# kics-scan ignore-block
resource "azurerm_storage_account" "pcaps_storage_account" {
  count = local.pcaps_storage_enable ? 1 : 0

  name                            = local.pcaps_sa_name
  location                        = local.location
  resource_group_name             = local.rg.name
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  enable_https_traffic_only       = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  public_network_access_enabled   = true
  nfsv3_enabled                   = false
  sftp_enabled                    = false

  tags = local.all_tags
}

resource "azurerm_storage_account_network_rules" "pcaps_storage_network" {
  count = local.pcaps_storage_enable ? 1 : 0
  # Network rule to allow access to vSensors via subnet and also terraform via public IP address
  # https://github.com/hashicorp/terraform-provider-azurerm/issues/2977
  storage_account_id         = azurerm_storage_account.pcaps_storage_account[0].id
  default_action             = "Deny"
  bypass                     = ["AzureServices"]
  ip_rules                   = var.terraform_cidrs
  virtual_network_subnet_ids = [local.subnet.id]
}

resource "azurerm_storage_container" "pcaps_storage_container" {
  count = local.pcaps_storage_enable ? 1 : 0

  name                  = local.pcaps_name
  storage_account_name  = azurerm_storage_account.pcaps_storage_account[0].name
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "pcaps_storage_policy" {
  count = local.pcaps_storage_enable ? 1 : 0

  storage_account_id = azurerm_storage_account.pcaps_storage_account[0].id
  rule {
    name    = "${local.pcaps_name}-lifecycle"
    enabled = true
    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["${local.pcaps_name}/chronicle/data/"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.lifecycle_pcaps_blob_days
        auto_tier_to_hot_from_cool_enabled                = false
      }
    }
  }
}

resource "azurerm_subnet_service_endpoint_storage_policy" "pcaps_service_endpoint_policy" {
  count = local.pcaps_storage_enable ? 1 : 0

  name                = "${local.pcaps_name}-service-endpoint"
  location            = local.location
  resource_group_name = local.rg.name
  definition {
    name              = "${local.pcaps_name}-service-endpoint-definition"
    service           = "Microsoft.Storage"
    service_resources = [azurerm_storage_account.pcaps_storage_account[0].id]
  }
  tags = local.all_tags
}


resource "azurerm_role_assignment" "pcaps_role_blob_contrib" {
  count = local.pcaps_storage_enable ? 1 : 0

  scope                = "${data.azurerm_subscription.subscription.id}/resourceGroups/${local.rg.name}/providers/Microsoft.Storage/storageAccounts/${local.pcaps_sa_name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine_scale_set.vsensor_vmss.identity[0].principal_id

}

resource "azurerm_role_assignment" "pcaps_role_storage_contrib" {
  count = local.pcaps_storage_enable ? 1 : 0

  scope                = "${data.azurerm_subscription.subscription.id}/resourceGroups/${local.rg.name}/providers/Microsoft.Storage/storageAccounts/${local.pcaps_sa_name}"
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_linux_virtual_machine_scale_set.vsensor_vmss.identity[0].principal_id

}
