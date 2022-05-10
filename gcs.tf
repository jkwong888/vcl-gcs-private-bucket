# make sure the bucket is created by the same SA that verified DNS
provider "google" {
  alias = "bucketcreator"
  credentials = base64decode(google_service_account_key.siteverifier.private_key)
}

# allow site verifier to create buckets
resource "google_project_iam_member" "siteverifier_bucketCreator" {
  project       = module.service_project.project_id
  member        = format("serviceAccount:%s", google_service_account.siteverifier.email)
  role          = "roles/storage.admin"
}

resource "google_storage_bucket" "private-data" {
  provider    = google.bucketcreator

  depends_on  = [
    googlesiteverification_dns.domain,
    google_project_iam_member.siteverifier_bucketCreator,
  ]

  project       = module.service_project.project_id
  #name          = format("%s-%s", var.service_project_id, random_id.id.hex)
  name          = var.bucket_domain
  location      = "US"
  force_destroy = true

  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "private-data2" {
  project       = module.service_project.project_id
  name          = format("%s-%s", var.service_project_id, random_id.id.hex)
  location      = "US"
  force_destroy = true

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "hmac_test" {
  name   = "hmac-test.txt"
  content = <<EOT
test hmac data! ${google_storage_bucket.private-data.name} ${random_id.id.hex}
EOT
  bucket = google_storage_bucket.private-data.name
}

resource "google_storage_bucket_object" "hmac_test2" {
  name   = "hmac-test.txt"
  content = <<EOT
test hmac data! ${google_storage_bucket.private-data2.name} ${random_id.id.hex}
EOT
  bucket = google_storage_bucket.private-data2.name
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

resource "google_storage_bucket_iam_member" "gcs_reader2" {
  bucket = google_storage_bucket.private-data2.name
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