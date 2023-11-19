terraform {
  backend "gcs" {
    bucket = "coilysiren-zapier-interview-tfstate-0"
    prefix = "terraform/state"
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs
provider "google" {
  project = "root-territory-384205"
  region  = "us-central1"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
data "google_client_config" "default" {}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project
data "google_project" "default" {}

# this bucket was created manually, and then imported into terraform afterwards
# `terraform import google_storage_bucket.default coilysiren-zapier-interview-tfstate-0`
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
resource "google_storage_bucket" "default" {
  name          = "coilysiren-zapier-interview-tfstate-0"
  location      = "US-CENTRAL1"
  force_destroy = true
  project       = data.google_project.default.project_id
}
