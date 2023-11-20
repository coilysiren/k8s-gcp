locals {
  name = yamldecode(file("../../config.yml")).name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
data "google_client_config" "default" {}

data "kubernetes_service" "service" {
  metadata {
    name = "application"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone
data "aws_route53_zone" "zone" {
  name         = "coilysiren.me."
  private_zone = false
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
resource "aws_route53_record" "record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "${local.name}.coilysiren.me."
  type    = "A"
  ttl     = "300"
  records = [data.kubernetes_service.service.status.0.load_balancer.0.ingress.0.ip]
}
