terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }
}

provider "aws" {
  region = local.aws_region
}

# Uses the kubeconfig written by scripts/deploy_cluster.sh
# (aws eks update-kubeconfig --alias <cluster>-admin) once the cluster exists.
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "${data.terraform_remote_state.cluster.outputs.cluster_name}-admin"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "${data.terraform_remote_state.cluster.outputs.cluster_name}-admin"
  }
}

locals {
  # Fixed, not a variable — see terraform/cluster/locals.tf.
  aws_region = "us-west-2"
}

# Reads this repo's own terraform/cluster state — same bridging pattern
# terraform/cluster uses to read coder-demo-eks's core-infra state.
data "terraform_remote_state" "cluster" {
  backend = "local"
  config = {
    path = "${path.module}/../cluster/terraform.tfstate"
  }
}
