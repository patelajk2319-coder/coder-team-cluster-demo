variable "platform_state_path" {
  description = "Path to coder-demo-eks/terraform/core-infra's state file — read for the VPC peering connection in peering.tf"
  type        = string
  default     = "../../../coder-demo-eks/terraform/core-infra/terraform.tfstate"
}

# 10.1.0.0/16 — deliberately a different range from coder-demo-eks's
# 10.0.0.0/16, since the two VPCs will be peered.
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
  description = "EC2 instance type for the system node group"
  type        = string
  default     = "m6i.large"
}

variable "node_desired_count" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "node_min_count" {
  description = "Minimum node count for the autoscaler"
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximum node count for the autoscaler"
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
