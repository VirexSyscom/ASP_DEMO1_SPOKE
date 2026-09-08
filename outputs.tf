output "resource_group_name" {
  value = data.azurerm_resource_group.hr.name
}

output "existing_network" {
  value = {
    vnet_name                  = data.azurerm_virtual_network.uat.name
    vm_subnet_id               = data.azurerm_subnet.vm.id
    private_endpoint_subnet_id = data.azurerm_subnet.pe.id
  }
}

output "vm" {
  value = {
    id   = azurerm_windows_virtual_machine.cm_hr_test.id
    name = azurerm_windows_virtual_machine.cm_hr_test.name
    nic_ids = [
      azurerm_network_interface.cm_hr_test_primary.id,
      azurerm_network_interface.cm_hr_test_secondary.id
    ]
  }
}

output "sql" {
  value = {
    server_id           = azurerm_mssql_server.hr.id
    database_id         = azurerm_mssql_database.hrdata.id
    private_endpoint_id = azurerm_private_endpoint.sql.id
  }
}

output "storage" {
  value = {
    account_id          = azurerm_storage_account.syscom.id
    private_endpoint_id = azurerm_private_endpoint.storage_blob.id
    system_topic_id     = azurerm_eventgrid_system_topic.storage.id
  }
}

output "monitoring" {
  value = {
    action_group_id = azurerm_monitor_action_group.vm.id
    metric_alert_id = azurerm_monitor_metric_alert.vm_availability.id
  }
}
