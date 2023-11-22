locals {
  zone   = yamldecode(file("../../config.yml")).zone
  domain = yamldecode(file("../../config.yml")).domain
}

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/ingress_v1
data "kubernetes_ingress_v1" "ingress" {
  metadata {
    name = "application-ingress"
  }
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
  records = [data.kubernetes_ingress_v1.ingress.status.0.load_balancer.0.ingress.0.ip]
}
