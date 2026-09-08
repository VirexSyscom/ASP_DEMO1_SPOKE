############################################
# providers.tf
#   整合自 1_providers / 2_providers
#   - required_version 取較嚴格者：>= 1.9.0
#   - azurerm 鎖在 4.x：~> 4.10
#       * Bastion Developer SKU 需要 4.x
#       * 不可放寬到 5.x（private_dns_zone_virtual_network_link 有破壞性變更）
#   - random 供 SQL Server / Storage Account 全域唯一名稱使用
#   - 原 2_providers 的 azapi 未被任何資源使用，整合後移除
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
