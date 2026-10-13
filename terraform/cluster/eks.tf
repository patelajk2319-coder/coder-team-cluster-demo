# Registry module, not hand-rolled.

# The module sets bootstrap_self_managed_addons = false, unlike a plain
# aws_eks_cluster — vpc-cni/kube-proxy need before_compute to bootstrap nodes.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${local.name_prefix}-eks"
  kubernetes_version = var.kubernetes_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = concat(module.vpc.public_subnets, module.vpc.private_subnets)

  endpoint_public_access  = true
  endpoint_private_access = true

  # Modern IAM-native cluster access (replaces the legacy aws-auth ConfigMap).
  authentication_mode = "API"

  # Grants the deployer cluster-admin — resolves the real IAM role ARN for
  # SSO/assumed-role callers internally (aws_iam_session_context).
  enable_cluster_creator_admin_permissions = true

  enabled_log_types = ["api", "audit", "authenticator"]

  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = var.log_retention_days

  enable_irsa = true

  addons = {
    vpc-cni = {
      before_compute = true
    }
    kube-proxy = {
      before_compute = true
    }
    # Every pool is tainted — no untainted fallback for CoreDNS to land on.
    coredns = {
      configuration_values = jsonencode({
        nodeSelector = { "coder.com/node-pool" = "system" }
        tolerations = [
          { key = "CriticalAddonsOnly", operator = "Exists" },
          { key = "node-role.kubernetes.io/control-plane", effect = "NoSchedule" },
          { key = "coder.com/node-pool", operator = "Equal", value = "system", effect = "NoSchedule" },
        ]
      })
    }
  }

  # Dedicated node pools, labeled + tainted — see README's Node Pools section.
  eks_managed_node_groups = {
    system = {
      instance_types = [var.node_instance_type]

      min_size     = var.node_min_count
      max_size     = var.node_max_count
      desired_size = var.node_desired_count

      labels = {
        "coder.com/node-pool" = "system"
      }
      taints = {
        dedicated = {
          key    = "coder.com/node-pool"
          value  = "system"
          effect = "NO_SCHEDULE"
        }
      }
    }

    provisioner = {
      instance_types = [var.provisioner_node_instance_type]

      min_size     = var.provisioner_node_min_count
      max_size     = var.provisioner_node_max_count
      desired_size = var.provisioner_node_desired_count

      labels = {
        "coder.com/node-pool" = "provisioner"
      }
      taints = {
        dedicated = {
          key    = "coder.com/node-pool"
          value  = "provisioner"
          effect = "NO_SCHEDULE"
        }
      }
    }

    workspaces = {
      instance_types = [var.workspace_node_instance_type]

      min_size     = var.workspace_node_min_count
      max_size     = var.workspace_node_max_count
      desired_size = var.workspace_node_desired_count

      labels = {
        "coder.com/node-pool" = "workspaces"
      }
      taints = {
        dedicated = {
          key    = "coder.com/node-pool"
          value  = "workspaces"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  tags = local.common_tags
}
