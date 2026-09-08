############################################
# 統一命名與標籤邏輯（網路 / HR 共用）
############################################
data "azurerm_client_config" "current" {}

locals {
  # 前綴：留空時不加分隔符號，例如 name_prefix = "demo" -> "demo-"
  prefix = var.name_prefix == "" ? "" : "${var.name_prefix}${var.name_separator}"

  # 供不允許連字號的資源（如 SQL Server、Compute Gallery）使用的緊湊前綴
  prefix_compact = lower(replace(var.name_prefix, "-", ""))

  # ---------- 統一命名表 ----------
  name = {
    # 網路層
    spoke_vnet       = "${local.prefix}Spoke-VNET"
    uat_spoke_vnet   = "${local.prefix}UAT-Spoke-VNET"
    ap_subnet        = "${local.prefix}AP-Subnet"
    db_subnet        = "${local.prefix}DB-Subnet"
    pe_subnet        = "${local.prefix}PrivateEndpoint-Subnet"
    uat_subnet       = "${local.prefix}Workload-Subnet"
    bastion_subnet   = "AzureBastionSubnet" # Azure 保留名稱，不可加前綴
    ap_nsg           = "${local.prefix}AP-Subnet-NSG"
    db_nsg           = "${local.prefix}DB-Subnet-NSG"
    nat_pip          = "${local.prefix}nat-pip-${var.location_short}"
    nat_gateway      = "${local.prefix}SpokeHRNatGW"
    bastion          = "${local.prefix}Spoke-VNET-bastion"
    alert_nsg_write  = "${local.prefix}Create or Update Network Security Group Alert"
    alert_nsg_delete = "${local.prefix}Delete Network Security Group Alert"

    # HR 工作負載層
    vm_identity      = "${local.prefix}vm-user-mid"
    lb_pip           = "${local.prefix}pip-hr-ap-${var.location_short}"
    lb               = "${local.prefix}hrap-lb"
    lb_frontend      = "${local.prefix}public-frontend"
    lb_backend_pool  = "${local.prefix}hr-backend-pool"
    lb_probe         = "${local.prefix}https-probe"
    lb_rule          = "${local.prefix}https-rule"
    nic_ipconfig     = "${local.prefix}ipconfig1"
    sql_server       = "${local.prefix_compact}cmhrsrv${random_string.sql_suffix.result}"
    sql_database     = "${local.prefix}hrdata"
    sql_pe           = "${local.prefix}cmhrsrv-pe"
    compute_gallery  = "${local.prefix_compact}cmgallery"
    shared_image     = "${local.prefix}hr-vm"
    ag_email         = "${local.prefix}email-alert"
    ag_vm            = "${local.prefix}vm-actiongroup"
    alert_sql_dtu    = "${local.prefix}dtu-percentage"
  }

  # ---------- 統一標籤 ----------
  common_tags = merge(
    {
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "Terraform"
      Location    = var.location
      Prefix      = var.name_prefix
    },
    var.cost_center == "" ? {} : { CostCenter = var.cost_center },
    var.tags
  )

  # 各層專屬標籤（在共用標籤之上疊加）
  network_tags = merge(local.common_tags, { Layer = "Network" }, var.network_tags)
  hr_tags      = merge(local.common_tags, { Layer = "Workload", Workload = "HR" }, var.hr_tags)

  # UAT 資源改寫 Environment
  uat_tags = merge(local.network_tags, { Environment = "uat" })

  # ---------- 資源群組解析 ----------
  network_rg_name     = var.create_network_resource_group ? azurerm_resource_group.network[0].name : data.azurerm_resource_group.network_existing[0].name
  network_rg_location = var.create_network_resource_group ? azurerm_resource_group.network[0].location : data.azurerm_resource_group.network_existing[0].location

  hr_rg_name     = var.create_hr_resource_group ? azurerm_resource_group.hr[0].name : data.azurerm_resource_group.hr_existing[0].name
  hr_rg_location = var.create_hr_resource_group ? azurerm_resource_group.hr[0].location : data.azurerm_resource_group.hr_existing[0].location

  subscription_id = data.azurerm_client_config.current.subscription_id
  alert_scope     = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"

  # 網路活動記錄警示：未指定 Action Group 時，沿用 HR 的 Email Action Group
  effective_alert_action_group_id = var.alert_action_group_id != "" ? var.alert_action_group_id : azurerm_monitor_action_group.email.id
}

resource "random_string" "sql_suffix" {
  length  = 4
  upper   = false
  special = false

  keepers = {
    prefix = local.prefix
  }
}

############################################
# 資源群組 1：網路（spoke-network-rg）
# 資源群組 2：HR 工作負載（Spoke-HR-RG）
#   兩者名稱皆不套用前綴，但一律套用統一標籤
############################################
data "azurerm_resource_group" "network_existing" {
  count = var.create_network_resource_group ? 0 : 1
  name  = var.network_resource_group_name
}

resource "azurerm_resource_group" "network" {
  count    = var.create_network_resource_group ? 1 : 0
  name     = var.network_resource_group_name
  location = var.location

  tags = merge(local.network_tags, {
    ResourceType = "ResourceGroup"
  })
}

data "azurerm_resource_group" "hr_existing" {
  count = var.create_hr_resource_group ? 0 : 1
  name  = var.hr_resource_group_name
}

resource "azurerm_resource_group" "hr" {
  count    = var.create_hr_resource_group ? 1 : 0
  name     = var.hr_resource_group_name
  location = var.location

  tags = merge(local.hr_tags, {
    ResourceType = "ResourceGroup"
  })
}

############################################
# 【網路】Virtual Network - Spoke-VNET（正式環境）
############################################
resource "azurerm_virtual_network" "spoke" {
  name                = local.name.spoke_vnet
  location            = local.network_rg_location
  resource_group_name = local.network_rg_name
  address_space       = var.spoke_vnet_address_space

  tags = merge(local.network_tags, {
    ResourceType = "VirtualNetwork"
    Tier         = "Spoke"
    Workload     = "Production"
  })
}

resource "azurerm_subnet" "ap" {
  name                 = local.name.ap_subnet
  resource_group_name  = local.network_rg_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.ap_subnet_prefix]
}

resource "azurerm_subnet" "db" {
  name                 = local.name.db_subnet
  resource_group_name  = local.network_rg_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.db_subnet_prefix]
}

resource "azurerm_subnet" "pe" {
  name                              = local.name.pe_subnet
  resource_group_name               = local.network_rg_name
  virtual_network_name              = azurerm_virtual_network.spoke.name
  address_prefixes                  = [var.pe_subnet_prefix]
  private_endpoint_network_policies = "Disabled"
}

# Bastion 專用子網路，名稱為 Azure 保留字，不可加前綴
# Developer SKU 不需要 AzureBastionSubnet，故為條件式建立
resource "azurerm_subnet" "bastion" {
  count                = var.create_bastion_subnet ? 1 : 0
  name                 = local.name.bastion_subnet
  resource_group_name  = local.network_rg_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

############################################
# 【網路】Virtual Network - UAT-Spoke-VNET（測試環境）
############################################
resource "azurerm_virtual_network" "uat_spoke" {
  name                = local.name.uat_spoke_vnet
  location            = local.network_rg_location
  resource_group_name = local.network_rg_name
  address_space       = var.uat_spoke_vnet_address_space

  tags = merge(local.uat_tags, {
    ResourceType = "VirtualNetwork"
    Tier         = "Spoke"
    Workload     = "UAT"
  })
}

resource "azurerm_subnet" "uat_workload" {
  name                 = local.name.uat_subnet
  resource_group_name  = local.network_rg_name
  virtual_network_name = azurerm_virtual_network.uat_spoke.name
  address_prefixes     = [var.uat_workload_subnet_prefix]
}

############################################
# 【網路】Network Security Group
############################################
resource "azurerm_network_security_group" "ap" {
  name                = local.name.ap_nsg
  location            = local.network_rg_location
  resource_group_name = local.network_rg_name

  tags = merge(local.network_tags, {
    ResourceType = "NetworkSecurityGroup"
    Tier         = "Application"
  })

  security_rule {
    name                       = "Allow-HTTPS-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-Internet-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "db" {
  name                = local.name.db_nsg
  location            = local.network_rg_location
  resource_group_name = local.network_rg_name

  tags = merge(local.network_tags, {
    ResourceType = "NetworkSecurityGroup"
    Tier         = "Database"
  })

  # 僅允許 AP Subnet 連 SQL
  security_rule {
    name                       = "Allow-SQL-From-AP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = var.ap_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "ap" {
  subnet_id                 = azurerm_subnet.ap.id
  network_security_group_id = azurerm_network_security_group.ap.id
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}

############################################
# 【網路】NAT Gateway
############################################
resource "azurerm_public_ip" "nat" {
  name                = local.name.nat_pip
  location            = local.network_rg_location
  resource_group_name = local.network_rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  tags = merge(local.network_tags, {
    ResourceType = "PublicIP"
    Purpose      = "NAT-Egress"
  })
}

resource "azurerm_nat_gateway" "spoke" {
  name                    = local.name.nat_gateway
  location                = local.network_rg_location
  resource_group_name     = local.network_rg_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4

  tags = merge(local.network_tags, {
    ResourceType = "NatGateway"
    Purpose      = "Outbound-Connectivity"
  })
}

resource "azurerm_nat_gateway_public_ip_association" "spoke" {
  nat_gateway_id       = azurerm_nat_gateway.spoke.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "ap" {
  subnet_id      = azurerm_subnet.ap.id
  nat_gateway_id = azurerm_nat_gateway.spoke.id
}

resource "azurerm_subnet_nat_gateway_association" "db" {
  subnet_id      = azurerm_subnet.db.id
  nat_gateway_id = azurerm_nat_gateway.spoke.id
}

############################################
# 【網路】Bastion（Developer SKU：無公用 IP）
#   1. Developer SKU 不需公用 IP，也不需 AzureBastionSubnet
#   2. 不支援 VNet peering，僅能連線 Spoke-VNET 內的 VM
#   3. 單一並行連線，且僅能透過 Azure 入口網站瀏覽器連線
#   4. 微軟定位為 Dev/Test，不建議用於正式環境
############################################
resource "azurerm_bastion_host" "spoke" {
  name                = local.name.bastion
  location            = local.network_rg_location
  resource_group_name = local.network_rg_name
  sku                 = var.bastion_sku

  # Developer SKU 以 VNet 為範圍，不使用 ip_configuration / public_ip
  virtual_network_id = azurerm_virtual_network.spoke.id
  copy_paste_enabled = true

  tags = merge(local.network_tags, {
    ResourceType = "Bastion"
    Purpose      = "SecureRemoteAccess"
    AccessModel  = "NoPublicIP-Developer"
    Scope        = "SpokeVNetOnly"
  })
}

############################################
# 【網路】Private DNS Zone
#   名稱由 Azure Private Link 規範固定，絕對不可加前綴
############################################
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = local.network_rg_name

  tags = merge(local.network_tags, {
    ResourceType = "PrivateDnsZone"
    Service      = "Storage-Blob"
  })
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_spoke" {
  name                  = "${local.prefix}link-spoke-vnet"
  resource_group_name   = local.network_rg_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false

  tags = merge(local.network_tags, {
    ResourceType = "PrivateDnsZoneLink"
  })
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_uat" {
  name                  = "${local.prefix}link-uat-spoke-vnet"
  resource_group_name   = local.network_rg_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.uat_spoke.id
  registration_enabled  = false

  tags = merge(local.uat_tags, {
    ResourceType = "PrivateDnsZoneLink"
  })
}

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = local.network_rg_name

  tags = merge(local.network_tags, {
    ResourceType = "PrivateDnsZone"
    Service      = "Azure-SQL"
  })
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_spoke" {
  name                  = "${local.prefix}link-spoke-vnet"
  resource_group_name   = local.network_rg_name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false

  tags = merge(local.network_tags, {
    ResourceType = "PrivateDnsZoneLink"
  })
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_uat" {
  name                  = "${local.prefix}link-uat-spoke-vnet"
  resource_group_name   = local.network_rg_name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.uat_spoke.id
  registration_enabled  = false

  tags = merge(local.uat_tags, {
    ResourceType = "PrivateDnsZoneLink"
  })
}

############################################
# 【網路】Activity Log Alert（location 固定 global）
############################################
resource "azurerm_monitor_activity_log_alert" "nsg_write" {
  name                = local.name.alert_nsg_write
  resource_group_name = local.network_rg_name
  location            = "global"
  scopes              = [local.alert_scope]
  description         = "當 NSG 被建立或更新時觸發"
  enabled             = true

  tags = merge(local.network_tags, {
    ResourceType = "ActivityLogAlert"
    Purpose      = "Security-Monitoring"
  })

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Network/networkSecurityGroups/write"
    level          = "Informational"
  }

  action {
    action_group_id = local.effective_alert_action_group_id
  }
}

resource "azurerm_monitor_activity_log_alert" "nsg_delete" {
  name                = local.name.alert_nsg_delete
  resource_group_name = local.network_rg_name
  location            = "global"
  scopes              = [local.alert_scope]
  description         = "當 NSG 被刪除時觸發"
  enabled             = true

  tags = merge(local.network_tags, {
    ResourceType = "ActivityLogAlert"
    Purpose      = "Security-Monitoring"
  })

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Network/networkSecurityGroups/delete"
    level          = "Informational"
  }

  action {
    action_group_id = local.effective_alert_action_group_id
  }
}

############################################
# 【HR】受控識別
############################################
resource "azurerm_user_assigned_identity" "vm" {
  name                = local.name.vm_identity
  location            = local.hr_rg_location
  resource_group_name = local.hr_rg_name

  tags = merge(local.hr_tags, {
    ResourceType = "ManagedIdentity"
  })
}

############################################
# 【HR】Load Balancer
############################################
resource "azurerm_public_ip" "lb" {
  name                = local.name.lb_pip
  location            = local.hr_rg_location
  resource_group_name = local.hr_rg_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(local.hr_tags, {
    ResourceType = "PublicIP"
    Purpose      = "LoadBalancer-Frontend"
  })
}

resource "azurerm_lb" "hr" {
  name                = local.name.lb
  location            = local.hr_rg_location
  resource_group_name = local.hr_rg_name
  sku                 = "Standard"

  tags = merge(local.hr_tags, {
    ResourceType = "LoadBalancer"
    Tier         = "Application"
  })

  frontend_ip_configuration {
    name                 = local.name.lb_frontend
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "hr" {
  name            = local.name.lb_backend_pool
  loadbalancer_id = azurerm_lb.hr.id
}

resource "azurerm_lb_probe" "https" {
  name            = local.name.lb_probe
  loadbalancer_id = azurerm_lb.hr.id
  protocol        = "Tcp"
  port            = 443
}

resource "azurerm_lb_rule" "https" {
  name                           = local.name.lb_rule
  loadbalancer_id                = azurerm_lb.hr.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = local.name.lb_frontend
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.hr.id]
  probe_id                       = azurerm_lb_probe.https.id
  disable_outbound_snat          = true
}

############################################
# 【HR】虛擬機器（直接掛載本組態建立的 AP-Subnet）
############################################
resource "azurerm_network_interface" "vm" {
  for_each = var.vm_names

  name                = "${local.prefix}${each.value}-nic"
  location            = local.hr_rg_location
  resource_group_name = local.hr_rg_name

  tags = merge(local.hr_tags, {
    ResourceType = "NetworkInterface"
  })

  ip_configuration {
    name                          = local.name.nic_ipconfig
    subnet_id                     = azurerm_subnet.ap.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "vm" {
  for_each = var.vm_names

  network_interface_id    = azurerm_network_interface.vm[each.value].id
  ip_configuration_name   = local.name.nic_ipconfig
  backend_address_pool_id = azurerm_lb_backend_address_pool.hr.id
}

resource "azurerm_windows_virtual_machine" "vm" {
  for_each = var.vm_names

  name                  = "${local.prefix}${each.value}"
  computer_name         = substr(replace("${local.prefix}${each.value}", "-", ""), 0, 15)
  location              = local.hr_rg_location
  resource_group_name   = local.hr_rg_name
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.vm[each.value].id]

  tags = merge(local.hr_tags, {
    ResourceType = "VirtualMachine"
    Tier         = "Application"
  })

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.vm.id]
  }

  os_disk {
    name                 = "${local.prefix}${each.value}-osdisk"
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

############################################
# 【HR】Azure SQL + Private Endpoint
#   PE 掛在網路層的 PrivateEndpoint-Subnet，
#   DNS 直接綁定網路層建立的 privatelink.database.windows.net
############################################
resource "azurerm_mssql_server" "hr" {
  name                          = local.name.sql_server
  resource_group_name           = local.hr_rg_name
  location                      = local.hr_rg_location
  version                       = "12.0"
  administrator_login           = var.sql_administrator_login
  administrator_login_password  = var.sql_administrator_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  tags = merge(local.hr_tags, {
    ResourceType = "SqlServer"
    Tier         = "Database"
  })
}

resource "azurerm_mssql_database" "hr" {
  name        = local.name.sql_database
  server_id   = azurerm_mssql_server.hr.id
  sku_name    = var.sql_database_sku
  max_size_gb = var.sql_database_max_size_gb

  tags = merge(local.hr_tags, {
    ResourceType = "SqlDatabase"
    Tier         = "Database"
  })
}

resource "azurerm_private_endpoint" "sql" {
  name                = local.name.sql_pe
  location            = local.hr_rg_location
  resource_group_name = local.hr_rg_name
  subnet_id           = azurerm_subnet.pe.id

  tags = merge(local.hr_tags, {
    ResourceType = "PrivateEndpoint"
    Service      = "Azure-SQL"
  })

  private_service_connection {
    name                           = "${local.prefix}cmhrsrv-connection"
    private_connection_resource_id = azurerm_mssql_server.hr.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${local.prefix}sql-private-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}

############################################
# 【HR】Compute Gallery
############################################
resource "azurerm_shared_image_gallery" "hr" {
  name                = local.name.compute_gallery
  resource_group_name = local.hr_rg_name
  location            = local.hr_rg_location
  description         = "HR VM image gallery"

  tags = merge(local.hr_tags, {
    ResourceType = "ComputeGallery"
  })
}

resource "azurerm_shared_image" "hr" {
  name                = local.name.shared_image
  gallery_name        = azurerm_shared_image_gallery.hr.name
  resource_group_name = local.hr_rg_name
  location            = local.hr_rg_location
  os_type             = "Windows"
  hyper_v_generation  = "V2"

  tags = merge(local.hr_tags, {
    ResourceType = "SharedImage"
  })

  identifier {
    publisher = "CM"
    offer     = "HR"
    sku       = "HR-VM"
  }
}

############################################
# 【HR】監控
############################################
resource "azurerm_monitor_action_group" "email" {
  name                = local.name.ag_email
  resource_group_name = local.hr_rg_name
  short_name          = substr("${local.prefix_compact}Email", 0, 12)

  tags = merge(local.hr_tags, {
    ResourceType = "ActionGroup"
    Purpose      = "Email-Notification"
  })

  email_receiver {
    name          = "operations"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_action_group" "vm" {
  name                = local.name.ag_vm
  resource_group_name = local.hr_rg_name
  short_name          = substr("${local.prefix_compact}VM", 0, 12)

  tags = merge(local.hr_tags, {
    ResourceType = "ActionGroup"
    Purpose      = "VM-Notification"
  })

  email_receiver {
    name          = "operations"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_metric_alert" "cpu" {
  for_each = azurerm_windows_virtual_machine.vm

  name                = "${local.prefix}cpu-${each.key}"
  resource_group_name = local.hr_rg_name
  scopes              = [each.value.id]
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  tags = merge(local.hr_tags, {
    ResourceType = "MetricAlert"
    Purpose      = "Performance-Monitoring"
  })

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.cpu_alert_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.vm.id
  }
}

resource "azurerm_monitor_metric_alert" "sql_dtu" {
  name                = local.name.alert_sql_dtu
  resource_group_name = local.hr_rg_name
  scopes              = [azurerm_mssql_database.hr.id]
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  tags = merge(local.hr_tags, {
    ResourceType = "MetricAlert"
    Purpose      = "Performance-Monitoring"
  })

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "dtu_consumption_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.dtu_alert_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}
