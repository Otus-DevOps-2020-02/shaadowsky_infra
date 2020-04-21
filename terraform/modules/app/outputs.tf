output "app_with_puma_external_ip" {
  value = ["${google_compute_instance.app_with_puma.*.network_interface.0.access_config.0.nat_ip}"]
}

output "app_without_puma_external_ip" {
  value = ["${google_compute_instance.app_without_puma.*.network_interface.0.access_config.0.nat_ip}"]
}
