#removed because of travis check doesn't pass
#terraform {
#  required_version = "0.12.24"
#}

provider "google" {
  version = "2.15.0"
  project = var.project
  region  = var.region
}

#adding ssh-keys into project's metadata
resource "google_compute_project_metadata_item" "ssh-keys" {
  key   = "ssh-keys"
  value = "${join("\n", var.public_key)}"
}

resource "google_compute_instance" "app" {
  name         = "reddit-app"
  machine_type = "f1-micro"
  zone         = var.zone
  boot_disk {
    initialize_params {
      image = var.disk_image
    }
  }
  metadata = {
    # путь до публичного ключа на локальной машине
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
  tags = ["reddit-app"]
  network_interface {
    network = "default"
    access_config {}
  }
  connection {
    type  = "ssh"
    host  = self.network_interface[0].access_config[0].nat_ip
    user  = "appuser"
    agent = false
    # путь до приватного ключа
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

# создаем правило файрволла
resource "google_compute_firewall" "firewall_puma" {
  name = "allow-puma-default"
  # Название сети, в которой действует правило
  network = "default"
  # Какой доступ разрешить
  allow {
    protocol = "tcp"
    ports    = ["9292"]
  }
  # Каким адресам разрешаем доступ
  source_ranges = ["0.0.0.0/0"]
  # Правило применимо для инстансов с перечисленными тэгами
  target_tags = ["reddit-app"]
}
