terraform {
  required_version = "~>0.12"
}

provider "google" {
  version = "2.15"
  project = var.project
  region  = var.region
}

# add ssh-keys into project
resource "google_compute_project_metadata_item" "appuser_key" {
  key   = "ssh-keys"
  value = var.ssh-keys
}

# add firewall rule for puma
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

#add firewall rule for SSH
resource "google_compute_firewall" "firewall_ssh" {
  name = "default-allow-ssh"
  network = "default"
  description = "Allow SSH from anywhere"
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

# add IP address as an external resource
resource "google_compute_address" "app_ip" {
  name = "reddit-app-ip"
}

# lets create instances
resource "google_compute_instance" "app" {
  #  count        = var.quantity
  name         = "reddit-app"
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
    access_config {
      nat_ip = google_compute_address.app_ip.address
    }
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
