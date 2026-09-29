resource "random_string" "bucket_name_suffix" {
  length  = 4
  special = false
  lower   = true
  upper   = false
}

resource "google_storage_bucket" "private_bucket" {
  name     = "${var.bucket_name_prefix}-${random_string.bucket_name_suffix.result}"
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true

  public_access_prevention = "enforced"

  # Object versioning is the recovery path for an accidental overwrite or a
  # ransomware-style mass delete. Without it the only recovery is restoring a backup
  # the bucket does not have, and the lifecycle rule below would make an overwrite
  # unrecoverable within a day.
  versioning {
    enabled = true
  }

  # Lifecycle management
  #
  # The previous rule deleted every object at age 1 with no `num_newer_versions`
  # condition, which combined with disabled versioning to mean that a single bad write
  # destroyed the prior content irrecoverably. The rule now only prunes *noncurrent*
  # superseded versions, so the live object is never removed by lifecycle.
  lifecycle_rule {
    condition {
      age            = 30
      num_newer_versions = 3
      with_state     = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # CORS configuration
  #
  # `origin = ["*"]` with a write verb lets any web page on the internet issue
  # cross-origin requests against this bucket. Combined with the credentialed S3-style
  # access the workload uses, that widens the blast radius of a single XSS in any
  # browser that holds a short-lived token. List the specific application origins that
  # need browser access instead; leave empty if the bucket is server-side only.
  cors {
    origin          = var.gcs_cors_origins
    method          = ["GET", "PUT"]
    response_header = ["*"]
  }

  force_destroy = !var.deletion_protection
}


