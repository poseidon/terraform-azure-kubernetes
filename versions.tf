# Terraform version and plugin versions

terraform {
  required_version = "~> 0.12.0"
  required_providers {
    azurerm  = "~> 1.27"
    ct       = "~> 0.3.2"
    template = "~> 2.1"
    null     = "~> 2.1"
  }
}

