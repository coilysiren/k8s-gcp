locals {
  name = yamldecode(file("../../config.yml")).name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
data "google_client_config" "default" {}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "gke" {
  account_id = local.name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
resource "google_project_iam_binding" "gkeartifactregistryreader" {
  project = data.google_client_config.default.project
  role    = "roles/artifactregistry.reader"

  members = [
    "serviceAccount:${google_service_account.gke.email}",
    "serviceAccount:${data.google_project.default.number}@cloudservices.gserviceaccount.com",
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
# https://mouliveera.medium.com/permissions-error-required-compute-instancegroups-update-permission-for-project-8a7f759c30c2
resource "google_project_iam_binding" "computeinstanceAdminv1" {
  project = data.google_client_config.default.project
  role    = "roles/compute.instanceAdmin.v1"

  members = [
    "serviceAccount:${data.google_project.default.number}@cloudservices.gserviceaccount.com",
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
# https://mouliveera.medium.com/permissions-error-required-compute-instancegroups-update-permission-for-project-8a7f759c30c2
resource "google_project_iam_binding" "computenetworkUser" {
  project = data.google_client_config.default.project
  role    = "roles/compute.networkUser"

  members = [
    "serviceAccount:${data.google_project.default.number}@cloudservices.gserviceaccount.com",
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
# https://mouliveera.medium.com/permissions-error-required-compute-instancegroups-update-permission-for-project-8a7f759c30c2
resource "google_project_iam_binding" "computeimageUser" {
  project = data.google_client_config.default.project
  role    = "roles/compute.imageUser"

  members = [
    "serviceAccount:${data.google_project.default.number}@cloudservices.gserviceaccount.com",
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
resource "google_project_iam_binding" "iamserviceAccountUser" {
  project = data.google_client_config.default.project
  role    = "roles/iam.serviceAccountUser"

  members = [
    "serviceAccount:${data.google_project.default.number}@cloudservices.gserviceaccount.com",
  ]
}

# https://registry.terraform.io/modules/terraform-google-modules/network/google/latest
module "vpc" {
  source       = "terraform-google-modules/network/google"
  project_id   = data.google_client_config.default.project
  network_name = local.name

  subnets = [
    {
      subnet_name           = "${local.name}-primary"
      subnet_private_access = "true"
      subnet_ip             = "10.0.0.0/20"
      subnet_region         = data.google_client_config.default.region
    },
    {
      subnet_name           = "${local.name}-secondary"
      subnet_private_access = "true"
      subnet_ip             = "10.0.16.0/20"
      subnet_region         = data.google_client_config.default.region
    },
  ]

  secondary_ranges = {
    "${local.name}-primary" = [
      {
        range_name    = "pods-range"
        ip_cidr_range = "10.0.32.0/20"
      },
      {
        range_name    = "services-range"
        ip_cidr_range = "10.0.48.0/20"
      },
    ],
    "${local.name}-secondary" = [
      {
        range_name    = "pods-range"
        ip_cidr_range = "10.0.64.0/20"
      },
      {
        range_name    = "services-range"
        ip_cidr_range = "10.0.80.0/20"
      },
    ],
  }
}

# https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/latest
module "gke" {
  name                      = local.name
  source                    = "terraform-google-modules/kubernetes-engine/google"
  project_id                = data.google_client_config.default.project
  region                    = data.google_client_config.default.region
  network                   = module.vpc.network_name
  subnetwork                = module.vpc.subnets_names[0]
  zones                     = ["${data.google_client_config.default.region}-a"] # default is every zone, we only want one for $$$ reasons
  remove_default_node_pool  = true
  deletion_protection       = false
  default_max_pods_per_node = 16
  initial_node_count        = 1
  ip_range_pods             = "pods-range"
  ip_range_services         = "services-range"
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster#nested_node_config
  node_pools = [
    {
      name            = "primary"
      machine_type    = "e2-small"
      min_count       = 1
      max_count       = 1
      auto_repair     = true
      auto_upgrade    = true
      service_account = google_service_account.gke.email
    },
  ]
  # https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/latest
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster#oauth_scopes
  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
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

output "endpoint" {
  value     = module.gke.endpoint
  sensitive = true
}

output "ca_certificate" {
  value     = module.gke.ca_certificate
  sensitive = true
}
