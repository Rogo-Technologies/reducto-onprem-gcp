resource "google_service_account" "service_account" {
  account_id   = "reducto-sa"
  display_name = "Reducto Service Account"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "gcs_object_admin" {
  bucket = google_storage_bucket.private_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "vertex_ai" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_storage_hmac_key" "s3_compatible_key" {
  service_account_email = google_service_account.service_account.email
}

# Secret Manager holds every credential the workload needs, so nothing sensitive is
# rendered into Terraform state. The application pod authenticates with Workload
# Identity (the KSA bound to this GSA via the GKE metadata server), which is the
# short-lived, automatically-rotating alternative to a downloaded service-account key.
# The HMAC key pair is the one exception: it is not a Google credential and must be
# written to Secret Manager explicitly.
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.service_account.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.workload_identity_ksa}]"
}

resource "google_secret_manager_secret" "credentials" {
  for_each = toset([
    "gcp-api-key",
    "gcp-access-key-id",
    "gcp-secret-access-key",
    "database-url",
  ])

  secret_id = "reducto-${each.key}"
  project   = var.project_id

  replication {
    auto {}
  }

  # Credential rotation is handled by the process that writes the secret version; the
  # accessor binding below grants the workload read access without granting project-wide
  # `secretmanager.secrets.get` on unrelated secrets.
  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_iam_member" "workload_reader" {
  for_each = google_secret_manager_secret.credentials

  project   = var.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.service_account.email}"
}

# Populate the non-Google credentials (S3-compatible HMAC pair, database URL). Each is
# written with `replication.automatic` disabled first so the version is immutable and
# cannot be silently replaced by a later `terraform apply` using different inputs.
resource "google_secret_manager_secret_version" "credentials" {
  for_each = {
    "gcp-access-key-id"     = google_storage_hmac_key.s3_compatible_key.access_id
    "gcp-secret-access-key" = google_storage_hmac_key.s3_compatible_key.secret
    "database-url"          = local.database_url
  }

  secret      = google_secret_manager_secret.credentials[each.key].id
  secret_data = each.value
}