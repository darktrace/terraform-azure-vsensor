resource "azurerm_monitor_data_collection_rule" "vsensor_data_collection" {
  name                = local.data_collection_name
  location            = local.location
  resource_group_name = local.rg.name
  description         = "Collect metrics from vSensor Scale Set"
  data_flow {
    streams      = ["Microsoft-InsightsMetrics"]
    destinations = ["VMInsightsPerf-Logs-Dest"]
  }
  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["VMInsightsPerf-Logs-Dest"]
  }
  data_sources {
    performance_counter {
      name                          = "VMInsightsPerfCounters"
      streams                       = ["Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 60
      counter_specifiers            = ["\\VmInsights\\DetailedMetrics"]
    }
    syslog {
      streams = ["Microsoft-Syslog"]
      facility_names = [
        "auth",
        "authpriv",
        "cron",
        "daemon",
        "mark",
        "kern",
        "local0",
        "local1",
        "local2",
        "local3",
        "local4",
        "local5",
        "local6",
        "local7",
        "lpr",
        "mail",
        "news",
        "syslog",
        "user",
        "uucp"
      ]
      log_levels = [
        "Debug",
        "Info",
        "Notice",
        "Warning",
        "Error",
        "Critical",
        "Alert",
        "Emergency"
      ]
      name = "Syslog"
    }
  }
  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.vsensor_logs.id
      name                  = "VMInsightsPerf-Logs-Dest"
    }
  }

  tags = local.all_tags
}

resource "azurerm_monitor_data_collection_rule_association" "vsensor_data_collection_assoc" {
  name                    = "${local.data_collection_name}-assoc"
  target_resource_id      = azurerm_linux_virtual_machine_scale_set.vsensor_vmss.id
  description             = "Association of data collection rule. Deleting this association will break the data collection for this virtual machine."
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vsensor_data_collection.id
}

resource "azurerm_log_analytics_workspace" "vsensor_logs" {
  name                            = "${local.deployment_id}-log"
  location                        = local.location
  resource_group_name             = local.rg.name
  sku                             = "PerGB2018"
  retention_in_days               = 30
  allow_resource_only_permissions = true
  local_authentication_disabled   = true
  internet_ingestion_enabled      = true
  internet_query_enabled          = true

  tags = local.all_tags
}
