locals {
  zone   = yamldecode(file("../../config.yml")).zone
  domain = yamldecode(file("../../config.yml")).domain
  email  = yamldecode(file("../../config.yml")).email
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user
resource "aws_iam_user" "user" {
  name = "certbot"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key
resource "aws_iam_access_key" "key" {
  user = aws_iam_user.user.name
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "policy" {
  name = "certbot"

  # https://cert-manager.io/docs/configuration/acme/dns01/route53/
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow",
        Action   = "route53:ChangeResourceRecordSets",
        Resource = data.aws_route53_zone.zone.arn,
      },
      {
        Effect = "Allow"
        Action = [
          "route53:Get*",
          "route53:List*",
        ]
        Resource = "*"
      },
    ]
  })
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment
resource "aws_iam_user_policy_attachment" "test-attach" {
  user       = aws_iam_user.user.name
  policy_arn = aws_iam_policy.policy.arn
}

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret
resource "kubernetes_secret" "secret" {
  metadata {
    name = "route53-credentials-secret"
  }

  data = {
    "access-key-id"     = aws_iam_access_key.key.id
    "secret-access-key" = aws_iam_access_key.key.secret
  }
}

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret
resource "kubernetes_secret" "cert" {
  metadata {
    name = "web-ssl"
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = ""
    "tls.key" = ""
  }
  lifecycle {
    ignore_changes = [
      metadata,
      data,
    ]
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone
data "aws_route53_zone" "zone" {
  name         = "${local.zone}."
  private_zone = false
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address
resource "google_compute_address" "address" {
  name         = "application-ingress"
  address_type = "EXTERNAL"
}
