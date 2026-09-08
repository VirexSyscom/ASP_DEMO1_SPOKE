variable "subscription_id" {
  description = "Azure 訂閱 ID；留空時由 Azure DevOps ARM_SUBSCRIPTION_ID 注入"
  type        = string
  default     = null
  nullable    = true
}

variable "location" {
  type    = string
  default = "japaneast"
}

variable "resource_group_name" {
  description = "所有新增 HR 資源固定放入既有資源群組"
  type        = string
  default     = "UAT-Spoke-HR-RG"
}

variable "network_resource_group_name" {
  description = "既有 UAT VNet 所在資源群組"
  type        = string
  default     = "spoke-network-rg"
}

variable "existing_vnet_name" {
  description = "沿用的既有 UAT VNet"
  type        = string
  default     = "UAT-Spoke-VNET"
}

variable "existing_vm_subnet_name" {
  description = "VM 網卡沿用的既有子網路"
  type        = string
  default     = "Workload-Subnet"
}

variable "existing_private_endpoint_subnet_name" {
  description = "SQL 與 Storage Private Endpoint 沿用的既有子網路"
  type        = string
  default     = "PrivateEndpoint-Subnet"
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "sql_administrator_login" {
  type    = string
  default = "sqladminuser"
}

variable "sql_administrator_password" {
  type      = string
  sensitive = true
}

variable "sql_database_sku" {
  type    = string
  default = "S0"
}

variable "alert_email" {
  type    = string
  default = "virex_lai@syscom.com.tw"
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "UAT"
    Workload    = "HR"
    ManagedBy   = "Terraform"
  }
}
