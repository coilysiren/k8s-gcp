terraform {
  backend "gcs" {
    bucket = "coilysiren-k8s-gpc-tfstate-5"
    prefix = "terraform/state/application"
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

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
provider "kubernetes" {
  host                   = "https://${data.terraform_remote_state.foundation.outputs.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.terraform_remote_state.foundation.outputs.ca_certificate)
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
provider "aws" {
  # AWS doesn't have the same regions as GCP, and also doesn't format then in the same way.
  # That said, this isn't a huge issue because we are only using AWS for DNS.
  region  = "us-east-1"
  profile = "coilysiren"
}

data "terraform_remote_state" "foundation" {
  backend = "gcs"
  config = {
    bucket = local.statebucket
    prefix = "terraform/state"
  }
}
