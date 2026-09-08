############################################
# 共用：命名與標籤驗證
############################################
output "name_prefix_applied" {
  description = "實際套用的前綴字串"
  value       = local.prefix
}

output "resource_names" {
  description = "所有資源的最終名稱，可用於驗證前綴是否正確套用"
  value       = local.name
}

output "common_tags" {
  description = "套用到所有資源的共用標籤基準"
  value       = local.common_tags
}

output "network_tags_applied" {
  description = "網路資源群組套用的標籤"
  value       = local.network_tags
}

output "hr_tags_applied" {
  description = "HR 資源群組套用的標籤"
  value       = local.hr_tags
}

############################################
# 資源群組
############################################
output "resource_groups" {
  description = "本組態管理的兩個資源群組"
  value = {
    network = local.network_rg_name
    hr      = local.hr_rg_name
  }
}

############################################
# 網路層
############################################
output "spoke_vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "uat_spoke_vnet_id" {
  value = azurerm_virtual_network.uat_spoke.id
}

output "subnet_ids" {
  value = {
    ap      = azurerm_subnet.ap.id
    db      = azurerm_subnet.db.id
    pe      = azurerm_subnet.pe.id
    bastion = var.create_bastion_subnet ? azurerm_subnet.bastion[0].id : null
    uat     = azurerm_subnet.uat_workload.id
  }
}

output "nat_gateway_public_ip" {
  value = azurerm_public_ip.nat.ip_address
}

output "private_dns_zone_ids" {
  value = {
    blob = azurerm_private_dns_zone.blob.id
    sql  = azurerm_private_dns_zone.sql.id
  }
}

output "bastion_id" {
  description = "Bastion Host 資源 ID"
  value       = azurerm_bastion_host.spoke.id
}

output "bastion_sku" {
  description = "實際部署的 Bastion SKU"
  value       = azurerm_bastion_host.spoke.sku
}

output "bastion_access_model" {
  description = "Bastion 連線方式說明"
  value       = var.bastion_sku == "Developer" ? "Developer SKU：無公用 IP，僅限 Azure 入口網站連線同一 VNet 內的 VM" : "使用公用 IP 連線"
}

############################################
# HR 工作負載層
############################################
output "virtual_machine_names" {
  value = [for vm in azurerm_windows_virtual_machine.vm : vm.name]
}

output "load_balancer_public_ip" {
  value = azurerm_public_ip.lb.ip_address
}

output "sql_server_name" {
  value = azurerm_mssql_server.hr.name
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.hr.fully_qualified_domain_name
}

output "sql_private_endpoint_ip" {
  value = azurerm_private_endpoint.sql.private_service_connection[0].private_ip_address
}

output "compute_gallery_name" {
  value = azurerm_shared_image_gallery.hr.name
}

output "vm_user_assigned_identity_id" {
  value = azurerm_user_assigned_identity.vm.id
}
