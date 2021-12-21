terraform {
  required_providers {
    petstore = {
      source  = "terraform-in-action/petstore"
      version = "~> 1.0"
    }
  }
}

provider "petstore" {
  address = "http://localhost:8080/v2"
}

resource "petstore_pet" "pet" {
  name    = "snowball"
  status  = "available"
#  age     = 20
}