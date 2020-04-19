output "app_without_puma_external_ip" {
  value = module.app.app_without_puma_external_ip
}

output "app_with_puma_external_ip" {
  value = module.app.app_with_puma_external_ip
}

output "db_internal_ip" {
  value = module.db.db_internal_ip
}
