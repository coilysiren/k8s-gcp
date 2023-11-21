terraform {
  backend "gcs" {
    bucket = "coilysiren-k8s-gpc-tfstate-3"
    prefix = "terraform/state"
  }
}

locals {
  statebucket = yamldecode(file("../../config.yml")).statebucket
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs
provider "google" {
  project = yamldecode(file("../../config.yml")).project
  region  = yamldecode(file("../../config.yml")).region
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project
data "google_project" "default" {}

# this bucket was created manually, and then imported into terraform afterwards
#
#   $ terraform import google_storage_bucket.default coilysiren-k8s-gpc-tfstate-0
#
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
resource "google_storage_bucket" "default" {
  name          = local.statebucket
  location      = "US"
  force_destroy = true
  project       = data.google_project.default.project_id
}
