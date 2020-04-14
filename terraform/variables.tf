variable project {
  description = "Project ID"
}
variable region {
  description = "Region"
  # Значение по умолчанию
  default = "europe-north1"
}
variable zone {
  description = "Zone"
  default     = "europe-north1-c"
}
variable public_key_path {
  # Описание переменной
  description = "Path to the public key used for ssh access"
}
variable private_key_path {
  description = "Path to the private key used for ssh access"
}
variable disk_image {
  description = "Disk image"
}
variable port_app {
  description = "App port"
  default     = "9292"
}
variable quantity {
  type    = number
  default = 1
}
variable "ssh-keys" {
  type    = string
  default = null
}
