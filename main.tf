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

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "gke" {
  account_id = "gke-test-1"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
resource "google_project_iam_binding" "project" {
  project = data.google_client_config.default.project
  role    = "roles/editor"

  members = [
    "serviceAccount:${google_service_account.gke.email}",
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
}
