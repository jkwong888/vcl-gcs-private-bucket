resource "google_storage_bucket" "private-data" {
  project       = module.service_project.project_id
  #name          = format("%s-%s", var.service_project_id, random_id.id.hex)
  name          = var.bucket_domain
  location      = "US"
  force_destroy = true

  uniform_bucket_level_access = true
}

data "googlesiteverification_dns_token" "domain" {
  depends_on = [
    module.service_project.enabled_apis
  ]

  domain     = var.bucket_domain
}

data "google_dns_managed_zone" "parent_domain" {
  provider  = google-beta
  project   = var.shared_vpc_host_project_id
  name      = var.zone_name
}

resource "google_dns_record_set" "bucket_dns" {
  depends_on = [
    googlesiteverification_dns.domain,
  ]

  project       = var.shared_vpc_host_project_id
  provider      = google-beta
  managed_zone  = data.google_dns_managed_zone.parent_domain.name
  type          = data.googlesiteverification_dns_token.domain.record_type
  rrdatas       = [data.googlesiteverification_dns_token.domain.record_value]
  name          = format("%s.", data.googlesiteverification_dns_token.domain.record_name)
  ttl           = 60
}

resource "googlesiteverification_dns" "domain" {
  domain     = var.bucket_domain
  token      = data.googlesiteverification_dns_token.domain.record_value
  depends_on = [
    google_dns_record_set.bucket_dns,
  ]
}

resource "google_storage_bucket_object" "hmac_test" {
  name   = "hmac-test.txt"
  content = <<EOT
test hmac data! ${google_storage_bucket.private-data.name} ${random_id.id.hex}
EOT
  bucket = google_storage_bucket.private-data.name
}

resource "random_id" "id" {
  byte_length = 4
}

# Create a new service account
resource "google_service_account" "gcs_reader" {
  project       = module.service_project.project_id
  account_id = "gcs-reader"
}

#Create the HMAC key for the associated service account 
resource "google_storage_hmac_key" "key" {
  depends_on =  [
    google_project_organization_policy.service_account_key_creation_disable,
  ]

  project       = module.service_project.project_id
  service_account_email = google_service_account.gcs_reader.email
}

resource "google_storage_bucket_iam_member" "gcs_reader" {
  bucket = google_storage_bucket.private-data.name
  role = "roles/storage.objectViewer"
  member = format("serviceAccount:%s", google_service_account.gcs_reader.email)
}

resource "local_file" "init_vcl" {
  filename = "${path.module}/generated/init.vcl"
  content = templatefile(
    "${path.module}/tmpl/init.vcl.tmpl",
    {
      "GOOGLE_ACCESS_KEY" = google_storage_hmac_key.key.access_id
      "GOOGLE_SECRET_KEY" = google_storage_hmac_key.key.secret
      "GOOGLE_BUCKET" = google_storage_bucket.private-data.name
      "GOOGLE_REGION" = google_storage_bucket.private-data.location

    }

  )
}