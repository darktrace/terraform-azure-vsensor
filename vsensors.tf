resource "azurerm_linux_virtual_machine_scale_set" "vsensor_vmss" {
  depends_on = [
    azurerm_subnet_nat_gateway_association.vsensor_subnet_natgw,
    azurerm_subnet_network_security_group_association.vsensors_vmss_nsg_asoc
  ]
  name                = local.vmss_name
  location            = local.location
  resource_group_name = local.rg.name
  admin_username      = var.ssh_admin_username
  instances           = var.min_size
  sku                 = var.instance_size
  network_interface {
    name = "${local.vmss_name}-nic"
    ip_configuration {
      name                                   = "${local.vmss_name}-ipconfig"
      subnet_id                              = local.subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lb_backend.id]
      primary                                = true
    }
    enable_accelerated_networking = true
    enable_ip_forwarding          = true
    primary                       = true
  }
  os_disk {
    caching              = "ReadOnly"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }
  additional_capabilities {
    ultra_ssd_enabled = false
  }
  admin_ssh_key {
    public_key = var.ssh_pubkey
    username   = var.ssh_admin_username
  }
  automatic_instance_repair {
    enabled      = true
    grace_period = "PT10M"
  }
  # Health repair extension must be inline such that the above health repair config is valid
  # Because of conflict with azurerm_virtual_machine_scale_set_extension below, we must ignore_changes for this extension
  # Health check is unlikely to change, so this is safe.
  # This also has the effect of ignoring any extensions the customer may add later outside terraform.
  # LB backends also depend on attached VM scaleset, so replace this if we replace the lb_backend.
  lifecycle {
    ignore_changes       = [extension]
    replace_triggered_by = [azurerm_lb_backend_address_pool.lb_backend.id]
  }
  extension {
    name                       = "HealthRepairExtension"
    auto_upgrade_minor_version = true
    publisher                  = "Microsoft.ManagedServices"
    type                       = "ApplicationHealthLinux"
    type_handler_version       = "1.0"
    settings = jsonencode({
      protocol : "https"
      port : 443
      requestPath : "/healthcheck"
    })
  }
  identity {
    type = "SystemAssigned"
  }
  overprovision       = false
  upgrade_mode        = "Automatic"
  secure_boot_enabled = false
  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
  tags  = local.all_tags
  zones = var.zones
}

resource "azurerm_virtual_machine_scale_set_extension" "azure_monitor_extension" {
  name                         = "AzureMonitorLinuxAgent"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.vsensor_vmss.id
  publisher                    = "Microsoft.Azure.Monitor"
  type                         = "AzureMonitorLinuxAgent"
  type_handler_version         = "1.5"
  auto_upgrade_minor_version   = true
  automatic_upgrade_enabled    = true
}

resource "azurerm_virtual_machine_scale_set_extension" "vsensor_install" {
  depends_on = [
    azurerm_subnet_service_endpoint_storage_policy.pcaps_service_endpoint_policy,
    azurerm_role_assignment.pcaps_role_blob_contrib,
    azurerm_role_assignment.pcaps_role_storage_contrib,
    azurerm_role_assignment.vsensor_role_assign,
    azurerm_role_assignment.vsensor_role_assign_vnet,
    azurerm_storage_account_network_rules.pcaps_storage_network
  ]
  name                         = "DarktraceVSensorInstaller"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.vsensor_vmss.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.1"
  auto_upgrade_minor_version   = true
  settings = jsonencode({
    "skipDos2Unix" : false,
  })
  protected_settings = jsonencode({
    "script" : base64encode(templatefile("${path.module}/source/vsensor-init.sh", {
      vSensorUpdateKey         = var.update_key
      appliancePushtoken       = var.push_token
      applianceHostName        = var.instance_host_name
      appliancePort            = var.instance_port
      applianceProxy           = var.instance_proxy
      osSensorHMACToken        = var.os_sensor_hmac_token
      blobStorageEnable        = local.pcaps_storage_enable
      blobStorageAccountName   = local.pcaps_storage_enable ? azurerm_storage_account.pcaps_storage_account[0].name : ""
      blobStorageContainerName = local.pcaps_storage_enable ? azurerm_storage_container.pcaps_storage_container[0].name : ""
      loadBalancerDirectEnable = local.lb_direct_enable
      privateLinkIP            = azurerm_lb.lb.frontend_ip_configuration[1].private_ip_address
    }))
  })
}

resource "azurerm_monitor_autoscale_setting" "vmss_autoscale" {
  name                = "${local.vmss_name}-autoscaling"
  location            = local.location
  resource_group_name = local.rg.name
  profile {
    name = "Autoscale by percentage based on CPU usage"
    capacity {
      minimum = var.min_size
      maximum = var.max_size
      default = var.min_size
    }
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vsensor_vmss.id
        operator           = "GreaterThan"
        statistic          = "Average"
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
        threshold          = 70
      }
      scale_action {
        cooldown  = "PT5M"
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
      }
    }
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vsensor_vmss.id
        operator           = "LessThan"
        statistic          = "Average"
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
        threshold          = 50
      }
      scale_action {
        cooldown  = "PT5M"
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
      }
    }
  }
  target_resource_id = azurerm_linux_virtual_machine_scale_set.vsensor_vmss.id
  predictive {
    scale_mode      = "Enabled"
    look_ahead_time = "PT5M"
  }
  tags = local.all_tags
}

resource "azurerm_role_definition" "vsensor_role" {
  name        = "${local.vmss_name} vSensor Role"
  scope       = local.rg.id
  description = "Allows Darktrace vSensor to discover network properties for cloud tracking features."
  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachineScaleSets/read",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/networkInterfaces/read"
    ]
  }
  assignable_scopes = local.vnet_same_rg ? [local.rg.id] : [local.rg.id, local.vnet_rg.id]
}

resource "azurerm_role_assignment" "vsensor_role_assign" {
  scope                = local.rg.id
  role_definition_name = azurerm_role_definition.vsensor_role.name
  principal_id         = azurerm_linux_virtual_machine_scale_set.vsensor_vmss.identity[0].principal_id
  description          = "Allow vSensor to collect Darktrace / Cloud tracking metadata on the vSensor VNet."
}

resource "azurerm_role_assignment" "vsensor_role_assign_vnet" {
  count                = local.vnet_same_rg ? 0 : 1
  scope                = local.vnet_rg.id
  role_definition_name = azurerm_role_definition.vsensor_role.name
  principal_id         = azurerm_linux_virtual_machine_scale_set.vsensor_vmss.identity[0].principal_id
  description          = "Allow vSensor to collect Darktrace / Cloud tracking metadata on the vSensor VNet in a different resource group."
}
