#terraform {
#  required_version = "0.12.8"
#}

provider "google" {
  version = "2.15"
  project = var.project
  region  = var.region
}

# create instance
resource "google_compute_instance" "app" {
  count        = var.quantity
  name         = "reddit-app-${count.index}"
  machine_type = "f1-micro"
  zone         = var.zone
  tags         = ["reddit-app"]
  boot_disk {
    initialize_params {
      image = var.disk_image
    }
  }

  metadata = {
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }

  network_interface {
    network = "default"
    access_config {}
  }

  connection {
    type        = "ssh"
    host        = self.network_interface[0].access_config[0].nat_ip
    user        = "appuser"
    agent       = false
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    source      = "files/puma.service"
    destination = "/tmp/puma.service"
  }

  provisioner "remote-exec" {
    script = "files/deploy.sh"
  }
}

# 9292 healthcheck
resource "google_compute_http_health_check" "tcp-9292-check" {
  name               = "tcp-9292-check"
  request_path       = "/"
  port               = 9292
  check_interval_sec = 10
  timeout_sec        = 3
}

resource "google_compute_firewall" "firewall_puma" {
  name    = "allow-puma-default"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["9292"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["reddit-app"]
}

# ssh-keys
resource "google_compute_project_metadata_item" "ssh-keys" {
  key   = "ssh-keys"
  value = "${join("\n", var.public_key)}"
}

# resource pool
resource "google_compute_target_pool" "app-pool" {
  name      = "app-pool"
  region    = var.region
  instances = ["europe-north1-c/reddit-app"]
  health_checks = [
    google_compute_http_health_check.tcp-9292-connect.name
  ]
}
