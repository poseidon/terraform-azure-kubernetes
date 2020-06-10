# Terraform version and plugin versions

terraform {
  required_version = "~> 0.12.6"
  required_providers {
    azurerm  = "~> 2.8"
    ct       = "~> 0.4"
    template = "~> 2.1"
    null     = "~> 2.1"
  }
}

