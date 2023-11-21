locals {
  zone   = yamldecode(file("../../config.yml")).zone
  domain = yamldecode(file("../../config.yml")).domain
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
data "google_client_config" "default" {}

data "kubernetes_service" "service" {
  metadata {
    name = "application"
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/certificate_manager_dns_authorization
resource "google_certificate_manager_dns_authorization" "default" {
  name   = "dns-auth"
  domain = local.domain
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
  records = [data.kubernetes_service.service.status.0.load_balancer.0.ingress.0.ip]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
resource "aws_route53_record" "cert" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = google_certificate_manager_dns_authorization.default.dns_resource_record.0.name
  type    = google_certificate_manager_dns_authorization.default.dns_resource_record.0.type
  ttl     = "300"
  records = [google_certificate_manager_dns_authorization.default.dns_resource_record.0.data]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/certificate_manager_certificate
resource "google_certificate_manager_certificate" "default" {
  name  = "dns-cert"
  scope = "ALL_REGIONS"
  managed {
    domains = [
      google_certificate_manager_dns_authorization.default.domain,
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.default.id,
    ]
  }
}
