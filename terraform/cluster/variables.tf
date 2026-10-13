# The control plane this cluster peers with — see peering.tf. No sensible
# default; every value here is specific to whichever platform repo you're
# pairing with, so all four are required.

variable "platform_state_path" {
  description = "Path to the control plane's core-infra Terraform state file"
  type        = string
}

variable "platform_region" {
  description = "AWS region the control plane runs in"
  type        = string
}

variable "platform_vpc_name" {
  description = "Name tag of the control plane's VPC — its route tables are tagged <name>-public/-private"
  type        = string
}

variable "platform_cluster_name" {
  description = "Name of the control plane's EKS cluster — tags the NLB security group its ALB controller manages"
  type        = string
}

# 10.1.0.0/16 — deliberately a different range from the platform's, since
# the two VPCs are peered.
variable "vpc_cidr" {
  description = "CIDR block for this cluster's own VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.1.0.0/24", "10.1.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private node subnets (one per AZ)"
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "EC2 instance type for the system node pool (EKS/AWS infra: EBS CSI driver)"
  type        = string
  default     = "m6i.large"
}

variable "node_desired_count" {
  description = "Desired node count for the system node pool"
  type        = number
  default     = 2
}

variable "node_min_count" {
  description = "Minimum node count for the system node pool's autoscaler"
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximum node count for the system node pool's autoscaler"
  type        = number
  default     = 3
}

variable "provisioner_node_instance_type" {
  description = "EC2 instance type for the provisioner node pool (the Coder provisioner daemon only)"
  type        = string
  default     = "m6i.large"
}

variable "provisioner_node_desired_count" {
  description = "Desired node count for the provisioner node pool"
  type        = number
  default     = 1
}

variable "provisioner_node_min_count" {
  description = "Minimum node count for the provisioner node pool's autoscaler"
  type        = number
  default     = 1
}

variable "provisioner_node_max_count" {
  description = "Maximum node count for the provisioner node pool's autoscaler"
  type        = number
  default     = 2
}

# Sized for coder-template-api-python's "large" (4 vCPU + dind's 250m).
variable "workspace_node_instance_type" {
  description = "EC2 instance type for the workspaces node pool (actual workspace pods)"
  type        = string
  default     = "m6i.2xlarge"
}

variable "workspace_node_desired_count" {
  description = "Desired node count for the workspaces node pool"
  type        = number
  default     = 1
}

variable "workspace_node_min_count" {
  description = "Minimum node count for the workspaces node pool's autoscaler"
  type        = number
  default     = 1
}

variable "workspace_node_max_count" {
  description = "Maximum node count for the workspaces node pool's autoscaler"
  type        = number
  default     = 3
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    project     = "coder-team-demo"
    managed-by  = "terraform"
    environment = "demo"
  }
}
