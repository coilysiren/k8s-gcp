locals {
  name   = yamldecode(file("../../config.yml")).name
  zone   = yamldecode(file("../../config.yml")).zone
  domain = yamldecode(file("../../config.yml")).domain
}

# docs: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "cluster" {
  name     = local.name
  location = data.google_client_config.default.region
  project  = data.google_client_config.default.project

  enable_autopilot    = true
  deletion_protection = false
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository
resource "google_artifact_registry_repository" "repository" {
  location      = data.google_client_config.default.region
  repository_id = "repository"
  format        = "DOCKER"

  docker_config {
    immutable_tags = true
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address
resource "google_compute_global_address" "address" {
  name = local.name
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone
data "aws_route53_zone" "zone" {
  name         = "${local.zone}."
  private_zone = false
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
resource "aws_route53_record" "record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "${local.domain}."
  type    = "A"
  ttl     = "300"
  records = [data.google_compute_addresses.address.addresses[0].address]
}

output "endpoint" {
  value     = google_container_cluster.cluster.endpoint
  sensitive = true
}

output "ca_certificate" {
  value     = google_container_cluster.cluster.master_auth.0.cluster_ca_certificate
  sensitive = true
}
