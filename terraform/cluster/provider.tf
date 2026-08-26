terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = local.aws_region
}

# Reads coder-demo-eks's core-infra state directly — the same
# terraform_remote_state bridging pattern that repo uses between its own
# terraform/{core-infra,addons,coder} directories, just crossing a repo
# boundary this time. Assumes both repos are checked out as sibling
# directories on the same machine — fine for this demo; a real cross-team
# setup would use a shared remote backend (S3 + cross-account IAM) instead
# of a local state file path.
data "terraform_remote_state" "platform" {
  backend = "local"
  config = {
    path = var.platform_state_path
  }
}
