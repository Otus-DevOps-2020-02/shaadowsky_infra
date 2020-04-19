#terraform {
#  required_version = "~>0.12"
#  backend "gcs" {
#    bucket = "stage-tf-back-stage"
#  }
#}

provider "google" {
  version = "~> 2.15"
  project = var.project
  region  = var.region
}

module "app" {
  env_sfx        = var.env
  source         = "../modules/app"
  db_internal_ip = module.db.db_internal_ip
  dep_sw         = var.dep_sw
}

module "db" {
  env_sfx = var.env
  source  = "../modules/db"
}

module "vpc" {
  source        = "../modules/vpc"
  source_ranges = var.source_ranges
}
