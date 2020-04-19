provider "google" {
  version = "~> 2.15"
  project = var.project
  region  = var.region
}

module "tf-backend-bucket-prod" {
  source   = "git::https://github.com/SweetOps/terraform-google-storage-bucket.git?ref=master"
  name     = "tf-back-prod"
  stage    = "prod"
  location = "europe-north1"
}

module "tf-backend-bucket-stage" {
  source   = "git::https://github.com/SweetOps/terraform-google-storage-bucket.git?ref=master"
  name     = "tf-back-stage"
  stage    = "stage"
  location = "europe-north1"
}

output tf-backend-bucket-prod-url {
  value = module.tf-backend-bucket-prod.url
}

output tf-backend-bucket-stage-url {
  value = module.tf-backend-bucket-stage.url
}
