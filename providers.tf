############################################
# Providers（合併 net_providers + hr_providers）
#   - required_version 取兩者較嚴格者：>= 1.9.0
#   - azurerm 鎖在 4.x：>= 4.10（Bastion Developer SKU 需要）
#     不可放寬到 5.x，azurerm 5.0 對
#     azurerm_private_dns_zone_virtual_network_link 有破壞性變更
#   - random 供 SQL Server 名稱亂數後綴使用
############################################
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

# subscription_id 留 null 時，provider 會自動採用 Azure DevOps
# Service Connection 注入的 ARM_SUBSCRIPTION_ID 環境變數。
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
