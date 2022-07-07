terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "eu-west-1"
  default_tags {
    tags = {
      product   = local.app_name
      workspace = terraform.workspace
    }
  }
}

locals {
  app_name             = "module-federation-poc"
  region               = "eu-west-1"
  lambda_consumer_name = "consumer"
  lambda_dcm_name      = "dcm"
  accountId            = "785508395937"
  stage_name           = "dev"
}
