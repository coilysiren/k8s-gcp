# https://registry.terraform.io/providers/hashicorp/google/latest/docs
provider "google" {
  region = "us-west1"
  zone   = "us-west1-c"
}

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
data "google_client_config" "default" {}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project
data "google_project" "project" {}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "gke" {
  account_id = "gke-test-1"
}

# # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
# resource "google_project_iam_binding" "artifactregistryreader" {
#   project = data.google_client_config.default.project
#   role    = "roles/artifactregistry.reader"

#   members = [
#     "serviceAccount:${google_service_account.gke.email}",
#   ]
# }

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
# https://mouliveera.medium.com/permissions-error-required-compute-instancegroups-update-permission-for-project-8a7f759c30c2
resource "google_project_iam_binding" "computeinstanceAdminv1" {
  project = data.google_client_config.default.project
  role    = "roles/compute.instanceAdmin.v1"

  members = [
    "serviceAccount:${data.google_project.project.number}@cloudservices.gserviceaccount.com",
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
# https://mouliveera.medium.com/permissions-error-required-compute-instancegroups-update-permission-for-project-8a7f759c30c2
resource "google_project_iam_binding" "computenetworkUser" {
  project = data.google_client_config.default.project
  role    = "roles/compute.networkUser"

  members = [
    "serviceAccount:${data.google_project.project.number}@cloudservices.gserviceaccount.com",
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
# https://mouliveera.medium.com/permissions-error-required-compute-instancegroups-update-permission-for-project-8a7f759c30c2
resource "google_project_iam_binding" "computeimageUser" {
  project = data.google_client_config.default.project
  role    = "roles/compute.imageUser"

  members = [
    "serviceAccount:${data.google_project.project.number}@cloudservices.gserviceaccount.com",
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
resource "google_project_iam_binding" "iamserviceAccountUser" {
  project = data.google_client_config.default.project
  role    = "roles/iam.serviceAccountUser"

  members = [
    "serviceAccount:${data.google_project.project.number}@cloudservices.gserviceaccount.com",
  ]
}

# https://registry.terraform.io/modules/terraform-google-modules/network/google/latest
module "vpc" {
  source       = "terraform-google-modules/network/google"
  project_id   = data.google_client_config.default.project
  network_name = "primary"

  subnets = [
    {
      subnet_name   = "primary"
      subnet_ip     = "10.0.0.0/24"
      subnet_region = data.google_client_config.default.region
    },
  ]

  secondary_ranges = {
    ("primary") = [
      {
        range_name    = "pods-range"
        ip_cidr_range = "10.0.1.0/24"
      },
      {
        range_name    = "services-range"
        ip_cidr_range = "10.0.2.0/24"
      },
    ]
  }
}

# https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/latest
module "gke" {
  name              = "gke-test-1"
  source            = "terraform-google-modules/kubernetes-engine/google"
  project_id        = data.google_client_config.default.project
  region            = data.google_client_config.default.region
  zones             = ["${data.google_client_config.default.region}-a"]
  network           = module.vpc.network_name
  subnetwork        = module.vpc.subnets_names[0]
  ip_range_pods     = "pods-range"
  ip_range_services = "services-range"

  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster#nested_node_config
  node_pools = [
    {
      name            = "primary"
      machine_type    = "e2-micro"
      min_count       = 1
      max_count       = 2
      auto_repair     = true
      auto_upgrade    = true
      service_account = google_service_account.gke.email
    },
  ]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository
resource "google_artifact_registry_repository" "k8s-gcp" {
  location      = data.google_client_config.default.region
  repository_id = "k8s-gcp"
  format        = "DOCKER"

  docker_config {
    immutable_tags = true
  }
}
