output "db_external_ip" {
  description = "External ip address db"
  value = google_compute_instance.db.network_interface[0].access_config[0].nat_ip
}

output "db_internal_ip" {
  description = "Internal ip address db"
  value       = google_compute_instance.db.network_interface[0].network_ip
}