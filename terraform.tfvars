############################################
# terraform.tfvars
#   整合自 1_terraform / 2_terraform
############################################

############################################
# 訂閱：由 Azure DevOps Service Connection 注入
# ARM_SUBSCRIPTION_ID，一般不需填寫
############################################
# subscription_id = "00000000-0000-0000-0000-000000000000"

############################################
# 命名前綴（Hub / Spoke / PROD-HR / UAT-HR 共用）
############################################
name_prefix    = "demo"
name_separator = "-"

############################################
# 基本設定
############################################
location       = "japaneast"
location_short = "jpe"

############################################
# 四個資源群組（名稱皆不套用前綴）
############################################
hub_resource_group_name   = "Hub-Network-RG"
create_hub_resource_group = true

network_resource_group_name   = "Spoke-Network-RG"
create_network_resource_group = true

hr_resource_group_name   = "Spoke-HR-RG"
create_hr_resource_group = true

uat_hr_resource_group_name   = "UAT-Spoke-HR-RG"
create_uat_hr_resource_group = true

############################################
# 標籤
############################################
environment = "prod"
owner       = "network-team"
cost_center = "CC-1001"

# 全域共用自訂標籤（同名時覆寫系統標籤）
tags = {
  Project      = "Hub-Spoke-Network"
  BusinessUnit = "HR"
  DataClass    = "Confidential"
  Criticality  = "High"
  ReviewDate   = "2027-01-01"
}

# 分層專屬標籤
hub_tags = {
  Workload = "Hub-Network"
}

network_tags = {}

hr_tags = {
  Application = "HR-System"
}

uat_hr_tags = {
  Application = "HR-System"
  Purpose     = "UAT"
}

############################################
# 網路位址 - Hub
############################################
hub_vnet_address_space      = ["10.0.0.0/16"]
hub_bastion_subnet_prefixes = ["10.0.0.0/26"]
gateway_subnet_prefixes     = ["10.0.1.0/27"]

############################################
# 網路位址 - Spoke（PROD / UAT）
############################################
spoke_vnet_address_space     = ["10.10.0.0/16"]
uat_spoke_vnet_address_space = ["10.20.0.0/16"]

ap_subnet_prefix           = "10.10.1.0/24"
db_subnet_prefix           = "10.10.2.0/24"
pe_subnet_prefix           = "10.10.3.0/24"
bastion_subnet_prefix      = "10.10.250.0/26" # Developer SKU 下不會被使用
uat_workload_subnet_prefix = "10.20.1.0/24"
uat_pe_subnet_prefix       = "10.20.2.0/24"

############################################
# Bastion
#   Hub  ：Basic，需公用 IP 與 AzureBastionSubnet
#   Spoke：Developer，不需公用 IP、不需 AzureBastionSubnet
#          限制：不支援 VNet peering、單一並行連線、僅限入口網站瀏覽器連線
############################################
hub_bastion_sku    = "Basic"
create_hub_bastion = true

bastion_sku           = "Developer"
create_bastion_subnet = false

############################################
# VPN Gateway / Site-to-Site
#   建立 VPN Gateway 約需 30-45 分鐘；
#   驗證階段可先設 create_vpn_gateway = false 加速部署。
############################################
create_vpn_gateway          = true
vpn_gateway_sku             = "VpnGw2AZ"
vpn_gateway_public_ip_zones = ["1", "2", "3"]
enable_bgp                  = false

onprem_vpn_public_ip = "203.0.113.10"
onprem_address_spaces = [
  "192.168.10.0/24",
  "192.168.20.0/24"
]

# create_vpn_connection = true 時，vpn_shared_key 必填
# 建議以環境變數注入：TF_VAR_vpn_shared_key
create_vpn_connection = false
# vpn_shared_key      = "***"

############################################
# Hub 與 Spoke 對等互連
############################################
enable_hub_spoke_peering = true

############################################
# 運算
############################################
vm_names = ["cm-hr-01", "cm-hr-02"]
vm_size  = "Standard_D2s_v5"

uat_vm_name           = "cm-hr-test"
uat_vm_size           = "Standard_D2s_v5"
uat_data_disk_size_gb = 128

admin_username = "azureadmin"
admin_password = "@Dmin9487"

############################################
# 資料庫
############################################
sql_administrator_login    = "sqladminuser"
sql_administrator_password = "@Dmin9487"

sql_database_sku         = "S0"
sql_database_max_size_gb = 10

uat_sql_database_sku         = "S0"
uat_sql_database_max_size_gb = 10

############################################
# 儲存體（UAT）
############################################
storage_replication_type          = "LRS"
create_uat_eventgrid_system_topic = true

############################################
# 監控
# alert_action_group_id 留空時，網路活動記錄警示
# 會自動沿用 PROD HR 的 Email Action Group
############################################
alert_email           = "virex_lai@syscom.com.tw"
alert_action_group_id = ""
cpu_alert_threshold   = 80
dtu_alert_threshold   = 80
