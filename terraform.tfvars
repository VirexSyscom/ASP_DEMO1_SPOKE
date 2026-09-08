############################################
# 訂閱：由 Azure DevOps Service Connection 注入
# ARM_SUBSCRIPTION_ID，一般不需填寫
############################################
# subscription_id = "00000000-0000-0000-0000-000000000000"

############################################
# 命名前綴（網路 / HR 共用）
############################################
name_prefix    = "demo"
name_separator = "-"

############################################
# 基本設定
############################################
location       = "japaneast"
location_short = "jpe"

############################################
# 兩個資源群組（名稱不套用前綴）
############################################
network_resource_group_name   = "Spoke-Network-RG"
create_network_resource_group = true

hr_resource_group_name   = "Spoke-HR-RG"
create_hr_resource_group = true

############################################
# 標籤
############################################
environment = "prod"
owner       = "network-team"
cost_center = "CC-1001"

# 全域共用自訂標籤（同名時覆寫系統標籤）
tags = {
  Project      = "Spoke-Network"
  BusinessUnit = "HR"
  DataClass    = "Confidential"
  Criticality  = "High"
  ReviewDate   = "2027-01-01"
}

# 分層專屬標籤
network_tags = {}
hr_tags = {
  Application = "HR-System"
}

############################################
# 網路位址
############################################
spoke_vnet_address_space     = ["10.10.0.0/16"]
uat_spoke_vnet_address_space = ["10.20.0.0/16"]

ap_subnet_prefix           = "10.10.1.0/24"
db_subnet_prefix           = "10.10.2.0/24"
pe_subnet_prefix           = "10.10.3.0/24"
bastion_subnet_prefix      = "10.10.250.0/26" # Developer SKU 下不會被使用
uat_workload_subnet_prefix = "10.20.1.0/24"

############################################
# Bastion
# Developer SKU：不需公用 IP、不需 AzureBastionSubnet
# 限制：不支援 VNet peering、單一並行連線、僅限入口網站瀏覽器連線
############################################
bastion_sku           = "Developer"
create_bastion_subnet = false

############################################
# 運算
############################################
vm_names       = ["cm-hr-01", "cm-hr-02"]
vm_size        = "Standard_D2s_v5"
admin_username = "azureadmin"
admin_password = "@Dmin9487"

############################################
# 資料庫
############################################
sql_administrator_login    = "sqladminuser"
sql_administrator_password = "@Dmin9487"
sql_database_sku           = "S0"
sql_database_max_size_gb   = 10

############################################
# 監控
# alert_action_group_id 留空時，網路活動記錄警示
# 會自動沿用 HR 的 Email Action Group
############################################
alert_email           = "virex_lai@syscom.com.tw"
alert_action_group_id = ""
cpu_alert_threshold   = 80
dtu_alert_threshold   = 80
