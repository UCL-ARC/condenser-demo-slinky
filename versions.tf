terraform {
  required_providers {

    harvester = {
      source  = "harvester/harvester"
      version = "~> 1.7.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.3.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.9.0"
    }
  }

  required_version = ">= 1.8.5"
}

provider "harvester" {
}
