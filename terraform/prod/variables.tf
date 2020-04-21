variable project {
  description = "Project ID"
  default     = "infra-272603"
}
variable region {
  description = "Region"
  default     = "europe-north1"
}
variable zone {
  description = "Zone"
  default     = "europe-north1-c"
}

variable source_ranges {}

variable env {}

variable dep_sw {
  type = bool
}
