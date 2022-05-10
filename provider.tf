terraform {
  backend "gcs" {
    bucket  = "jkwng-altostrat-com-tf-state"
    prefix = "jkwng-vcl-gcs-dev"
  }

  required_providers {
    google = {
      version = "~> 4.1.0"
      configuration_aliases = [google.bucketcreator]
    }
    google-beta = {
      version = "~> 4.1.0"

    }
    null = {
      version = "~> 2.1"
    }
    random = {
      version = "~> 2.2"
    }
    googlesiteverification = {
      source = "hectorj/googlesiteverification"
      version = "0.4.3"
    }
  }
}

provider "google" {
#  credentials = file(local.credentials_file_path)
}

provider "google-beta" {
#  credentials = file(local.credentials_file_path)
}

provider "null" {
}

provider "random" {
}


