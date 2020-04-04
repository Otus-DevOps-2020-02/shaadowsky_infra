output "app_external_ip" {
  value = "${google_compute_forwarding_rule.network-load-balancer.ip_address}"
}
