variable public_key_path {
  description = "Path to the public key used to connect to instance"
  default     = "~/.ssh/appuser.pub"
}

variable private_key_path {
  description = "Path to the public key used to connect to instance"
  default     = "~/.ssh/appuser"
}

variable zone {
  description = "Zone"
  default     = "europe-north1-c"
}

variable machine_type {
  description = "Machine type"
  default = "g1-small"
}

variable db_disk_image {
  description = "Disk image for reddit db"
  default     = "reddit-db-base"
}

variable env_sfx {}
