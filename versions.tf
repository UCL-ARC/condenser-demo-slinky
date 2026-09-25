terraform {
  required_providers {

    harvester = {
      source  = "harvester/harvester"
      version = "~> 1.7.0"
    }
  }

  required_version = ">= 1.8.5"
}

provider "harvester" {
}
