terraform {
  required_version = ">= 1.5.7" # terraform-aws-modules/eks//v21 requires >= 1.5.7

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # terraform-aws-modules/vpc//v6 and /eks//v21 require aws >= 6.28/6.59
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30" # matches coder-demo-eks/terraform/addons
    }
  }
  # tls/time/null/cloudinit come in implicitly via terraform-aws-modules/eks.
}

provider "aws" {
  region = local.aws_region
}

# Same state, same apply — no remote_state bridge needed (unlike
# coder-demo-eks's separate core-infra/addons split).
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "${module.eks.cluster_name}-admin"
}
