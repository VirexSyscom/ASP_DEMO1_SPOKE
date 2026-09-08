data "azurerm_resource_group" "hr" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "uat" {
  name                = var.existing_vnet_name
  resource_group_name = var.network_resource_group_name
}

data "azurerm_subnet" "vm" {
  name                 = var.existing_vm_subnet_name
  virtual_network_name = data.azurerm_virtual_network.uat.name
  resource_group_name  = var.network_resource_group_name
}

data "azurerm_subnet" "pe" {
  name                 = var.existing_private_endpoint_subnet_name
  virtual_network_name = data.azurerm_virtual_network.uat.name
  resource_group_name  = var.network_resource_group_name
}

# CM-HR-Test 的兩張網路介面，均沿用既有 UAT 網路
resource "azurerm_network_interface" "cm_hr_test_primary" {
  name                = "CM-HR-Test-nic-e3e1b8b6af894af8b9b8690bd71bbcaf"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.hr.name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

resource "azurerm_network_interface" "cm_hr_test_secondary" {
  name                = "CM-HR-Test-CM-HR-01-nic-ca7346c185604af9b9df6453e2c1792f"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.hr.name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "cm_hr_test" {
  name                = "CM-HR-Test"
  computer_name       = "CM-HR-Test"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.hr.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  tags                = var.tags

  network_interface_ids = [
    azurerm_network_interface.cm_hr_test_primary.id,
    azurerm_network_interface.cm_hr_test_secondary.id
  ]

  os_disk {
    name                 = "cmhrtest-osdisk-20260820-034916"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

# 圖片中的第二顆磁碟。因畫面無法確認原始容量與掛載本機代號，先以 128 GiB / LUN 1 建立。
resource "azurerm_managed_disk" "cm_hr_01_osdisk" {
  name                 = "cmhrtestcmhr01-osdisk-20260820-033218"
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.hr.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "cm_hr_01_osdisk" {
  managed_disk_id    = azurerm_managed_disk.cm_hr_01_osdisk.id
  virtual_machine_id = azurerm_windows_virtual_machine.cm_hr_test.id
  lun                = 1
  caching            = "ReadWrite"
}

resource "azurerm_mssql_server" "hr" {
  name                          = "uat-cmhrsrv"
  resource_group_name           = data.azurerm_resource_group.hr.name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = var.sql_administrator_login
  administrator_login_password  = var.sql_administrator_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_mssql_database" "hrdata" {
  name      = "HRdata"
  server_id = azurerm_mssql_server.hr.id
  sku_name  = var.sql_database_sku
  tags      = var.tags
}

resource "azurerm_private_endpoint" "sql" {
  name                = "uat-cmhrsrv"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.hr.name
  subnet_id           = data.azurerm_subnet.pe.id
  tags                = var.tags

  private_service_connection {
    name                           = "uat-cmhrsrv-connection"
    private_connection_resource_id = azurerm_mssql_server.hr.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
}

resource "azurerm_storage_account" "syscom" {
  name                          = "uatsyscom01"
  resource_group_name           = data.azurerm_resource_group.hr.name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "uatsyscom01-pe"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.hr.name
  subnet_id           = data.azurerm_subnet.pe.id
  tags                = var.tags

  private_service_connection {
    name                           = "uatsyscom01-blob-connection"
    private_connection_resource_id = azurerm_storage_account.syscom.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

resource "azurerm_eventgrid_system_topic" "storage" {
  name                   = "uatsyscom01-50657373-2561-4437-bb01-599ff0d8cd34"
  resource_group_name    = data.azurerm_resource_group.hr.name
  location               = var.location
  source_arm_resource_id = azurerm_storage_account.syscom.id
  topic_type             = "Microsoft.Storage.StorageAccounts"
  tags                   = var.tags
}

resource "azurerm_monitor_action_group" "vm" {
  name                = "VMI-ActionGroup-cm-1"
  resource_group_name = data.azurerm_resource_group.hr.name
  short_name          = "VMI-cm-1"
  tags                = var.tags

  email_receiver {
    name          = "operations"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_metric_alert" "vm_availability" {
  name                = "VM Availability - cm-1"
  resource_group_name = data.azurerm_resource_group.hr.name
  scopes              = [azurerm_windows_virtual_machine.cm_hr_test.id]
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "VmAvailabilityMetric"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.vm.id
  }
}
