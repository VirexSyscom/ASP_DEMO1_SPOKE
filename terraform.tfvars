# 訂閱 ID 由 Azure DevOps Service Connection 的 ARM_SUBSCRIPTION_ID 注入
# subscription_id = "00000000-0000-0000-0000-000000000000"

location            = "japaneast"
resource_group_name = "UAT-Spoke-HR-RG"

# 沿用既有網路，不建立新的 VNet 或 Subnet
network_resource_group_name              = "spoke-network-rg"
existing_vnet_name                       = "UAT-Spoke-VNET"
existing_vm_subnet_name                  = "Workload-Subnet"
existing_private_endpoint_subnet_name    = "PrivateEndpoint-Subnet"

vm_size        = "Standard_D2s_v5"
admin_username = "azureadmin"
admin_password = "@Dmin9487"

sql_administrator_login    = "sqladminuser"
sql_administrator_password = "@Dmin9487"
sql_database_sku           = "S0"

alert_email = "virex_lai@syscom.com.tw"

tags = {
  Environment = "UAT"
  Workload    = "HR"
  ManagedBy   = "Terraform"
  Application = "HR-System"
}
