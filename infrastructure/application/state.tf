terraform {
  backend "gcs" {
    bucket = "coilysiren-k8s-gpc-tfstate-0"
    prefix = "terraform/state/application"
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs
provider "google" {
  project = yamldecode(file("../../config.yml")).project
  region  = yamldecode(file("../../config.yml")).region
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project
data "google_project" "default" {}
