resource "google_compute_instance" "db" {
  name         = "${lower(var.env_sfx)}-reddit-db"
  machine_type = "f1-micro"
  zone         = var.zone
  tags         = ["reddit-db"]
  boot_disk {
    initialize_params {
      image = var.db_disk_image
    }
  }
  network_interface {
    network = "default"
  }
  metadata = {
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
}

resource "google_compute_firewall" "firewall_mongo" {
  name    = "allow-mongo-default"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }
  target_tags = ["reddit-db"]
  source_tags = ["reddit-app"]
}