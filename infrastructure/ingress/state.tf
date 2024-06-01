terraform {
  backend "gcs" {
    bucket = "coilysiren-k8s-gpc-tfstate-5"
    prefix = "terraform/state/ingress"
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

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
data "google_client_config" "default" {}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
provider "aws" {
  # AWS doesn't have the same regions as GCP, and also doesn't format then in the same way.
  # That said, this isn't a huge issue because we are only using AWS for DNS.
  region  = "us-east-1"
  profile = "coilysiren"
}
