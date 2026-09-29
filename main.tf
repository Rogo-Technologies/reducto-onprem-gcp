terraform {
  required_version = ">= 1.3"

  # The state file holds the database password and the S3-compatible HMAC secret (both
  # are also mirrored into Secret Manager, but they originate here). Without a remote
  # backend that state lives in a local `.terraform/terraform.tfstate`, which is easy
  # to commit, copy to a laptop, or lose with the working directory. Configure the
  # backend per-environment with `terraform init -backend-config=...`; the bucket must
  # have uniform bucket-level access, versioning, and public access prevention enabled.
  # NOTE: the bucket and lock table must already exist -- Terraform cannot create the
  # backend it stores its own state in.
  # backend "gcs" {
  #   bucket = "reducto-tfstate"
  #   prefix = "onprem"
  # }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.43.0, < 7"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.0"
    }
  }
}

data "google_client_config" "current" {
}

provider "helm" {
  kubernetes = {
    host  = "https://${module.gke.endpoint}"
    token = data.google_client_config.current.access_token
    cluster_ca_certificate = base64decode(
    module.gke.ca_certificate)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}

provider "kubectl" {
  host                   = module.gke.endpoint
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  token                  = data.google_client_config.current.access_token
  load_config_file       = false
}