locals {
  name_prefix = "coder-team-demo"

  # Fixed, not a variable — this is the whole point of this cluster: a team's
  # own region, deliberately different from coder-demo-eks's eu-west-1. That
  # means no shared VPC — this repo creates its own, connected back to the
  # control plane via VPC peering (see peering.tf) rather than living inside
  # the same network.
  aws_region = "us-west-2"

  common_tags = merge(var.tags, {
    region = local.aws_region
  })
}
