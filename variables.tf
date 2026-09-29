variable "project_id" {
  type        = string
  description = "The ID of the project where the network will be created"
}

variable "region" {
  type        = string
  description = "The region where the network will be created"
  default     = "us-west1"
}

variable "network_name" {
  type        = string
  description = "The name of the network to create"
  default     = "reducto-network"
}

variable "subnet_name" {
  type        = string
  description = "The name of the subnet to create"
  default     = "reducto-subnet"
}

variable "subnet_cidr" {
  type        = string
  description = "The CIDR block for the subnet"
  default     = "10.127.0.0/16"
}

# https://cloud.google.com/load-balancing/docs/proxy-only-subnets
variable "regional_proxy_subnet_cidr" {
  type        = string
  description = "The CIDR block for the regional proxy subnet for internal load balancing"
  default     = "10.129.0.0/16"
}

variable "pods_cidr_name" {
  type        = string
  description = "The name of the pods CIDR range"
  default     = "reducto-pods-range"
}

variable "pods_cidr" {
  type        = string
  description = "The CIDR block for the pods"
  default     = "10.131.0.0/16"
}

variable "services_cidr_name" {
  type        = string
  description = "The name of the services CIDR range"
  default     = "reducto-services-range"
}


variable "services_cidr" {
  type        = string
  description = "The CIDR block for the services"
  default     = "10.133.0.0/16"
}


variable "enable_apis" {
  type        = list(string)
  description = "The list of APIs to enable"
  default = [
    # for GKE
    "container.googleapis.com",
    # for accessing postgres on private network
    "servicenetworking.googleapis.com",
    # for Google Cloud Storage
    "storage.googleapis.com",
    # Enable API Keys (required for Reducto Vision API)
    "apikeys.googleapis.com",
    # for Google Cloud Vision
    "vision.googleapis.com",
    # for Secret Manager, which now holds the workload credentials
    "secretmanager.googleapis.com",
    # for Workload Identity binding
    "iam.googleapis.com",
  ]
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster"
  default     = "reducto-cluster"
}

variable "control_plane_allowed_cidrs" {
  type        = list(string)
  description = <<-EOT
    The list of CIDRs allowed to reach the GKE control plane.

    Defaults to empty, which leaves the control plane reachable only from the
    in-cluster node/pod ranges added in gke.tf. Do NOT widen this to "0.0.0.0/0":
    combined with `enable_private_endpoint = false` that publishes the Kubernetes
    API server to the public internet, where it is reachable by credential-stuffing
    and token-theft attacks. If an operator or CI runner outside the VPC must reach
    the API server, add only that egress NAT IP or VPN range.
  EOT
  default     = []

  validation {
    condition     = !contains(var.control_plane_allowed_cidrs, "0.0.0.0/0")
    error_message = "control_plane_allowed_cidrs must not contain 0.0.0.0/0: this would expose the GKE control plane to the public internet. Enumerate the specific operator or VPN CIDRs instead."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Whether to enable deletion protection on the cluster"
  default     = true
}

variable "bucket_name_prefix" {
  type        = string
  description = "The prefix for the bucket name"
  default     = "reducto"
}

variable "gcs_cors_origins" {
  type        = list(string)
  description = <<-EOT
    Origins permitted to make browser cross-origin requests to the bucket.

    Empty by default, which is correct for a server-to-server workload: the Reducto
    service reaches GCS from the pod, not from a browser. Add explicit origins (for
    example "https://app.example.com") only if a front-end needs direct bucket access.
    The wildcard "*" is rejected because it would let any page on the internet issue
    credentialed cross-origin reads and writes against this bucket.
  EOT
  default     = []

  validation {
    condition     = !contains(var.gcs_cors_origins, "*")
    error_message = "gcs_cors_origins must not contain the wildcard \"*\": enumerate the specific application origins that need browser access instead."
  }
}

variable "reducto_helm_repo_username" {
  description = "Username for Helm Registry for Reducto Helm Chart"
}

variable "reducto_helm_repo_password" {
  sensitive   = true
  description = "Password for Helm Registry for Reducto Helm Chart"
}

variable "reducto_helm_chart_version" {
  description = "Reducto Helm Chart version"
  default     = "1.9.93"
}

variable "reducto_helm_chart_oci" {
  description = "Path to Helm Chart on OCI registry"
  default     = "oci://registry.reducto.ai/reducto-api/reducto"
}

variable "reducto_host" {
  description = "Host for Reducto Ingress"
}

variable "db_availability_type" {
  description = "Availability type for the database"
  default     = "REGIONAL"
}

variable "db_tier" {
  description = "Tier for the database"
  default     = "db-custom-4-8192"
}

variable "namespace" {
  type        = string
  description = <<-EOT
    Kubernetes namespace the Reducto workload runs in. Used to build the Workload
    Identity principal (`<project>.svc.id.goog[<namespace>/<ksa>]`), which must match
    the namespace and service account the Helm release actually creates.
  EOT
  default     = "reducto"
}

variable "workload_identity_ksa" {
  type        = string
  description = "Kubernetes service account bound to the Reducto Google service account for Workload Identity."
  default     = "reducto"
}