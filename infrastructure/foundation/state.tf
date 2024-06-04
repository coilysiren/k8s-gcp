terraform {
  backend "gcs" {
    bucket = "coilysiren-k8s-gpc-tfstate-5"
    prefix = "terraform/state"
  }
}

locals {
  statebucket = yamldecode(file("../../config.yml")).statebucket
  project     = yamldecode(file("../../config.yml")).project
  region      = yamldecode(file("../../config.yml")).region
  aws-profile = yamldecode(file("../../config.yml")).aws-profile
  aws-region  = yamldecode(file("../../config.yml")).aws-region
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs
provider "google" {
  project = local.project
  region  = local.region
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
data "google_client_config" "default" {}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project
data "google_project" "default" {}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
provider "aws" {
  profile = local.aws-profile
  region  = local.aws-region
}

# this bucket was created manually, and then imported into terraform afterwards, example:
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
