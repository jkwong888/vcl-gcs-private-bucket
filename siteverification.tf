provider "googlesiteverification" {
  credentials = base64decode(google_service_account_key.siteverifier.private_key)
}

resource "google_service_account" "siteverifier" {
  project       = module.service_project.project_id
  account_id   = "google-site-verifier"
  display_name = "Google Site verification account"
}

resource "google_service_account_key" "siteverifier" {
  service_account_id = google_service_account.siteverifier.name
}

data "googlesiteverification_dns_token" "domain" {
  depends_on = [
    module.service_project.enabled_apis,
    google_service_account.siteverifier,
  ]

  domain     = var.bucket_domain
}

data "google_dns_managed_zone" "parent_domain" {
  project   = var.shared_vpc_host_project_id
  name      = var.zone_name
}

resource "google_dns_record_set" "bucket_dns_txt" {
  project       = var.shared_vpc_host_project_id
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
    google_dns_record_set.bucket_dns_txt,
  ]
}