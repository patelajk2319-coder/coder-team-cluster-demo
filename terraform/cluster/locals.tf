locals {
  name_prefix = "coder-team-demo"

  # Fixed, not a variable — deliberately a different region from the
  # control plane's, hence the VPC peering in peering.tf.
  aws_region = "eu-west-2"

  common_tags = merge(var.tags, {
    region = local.aws_region
  })
}
