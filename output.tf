output "bucket_url" {
    value = google_storage_bucket.private-data.url
}

output "hmac_access_id" {
    value = google_storage_hmac_key.key.access_id
}

output "hmac_access_secret" {
    value = google_storage_hmac_key.key.secret
    sensitive = true
}