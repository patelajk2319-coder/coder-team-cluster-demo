# Cross-region VPC peering back to coder-demo-eks (eu-west-1), so this
# cluster's provisioner can reach the control plane's internal NLB. This is
# the real trade-off flagged in the architecture sketch for genuinely
# separate infrastructure: no shared VPC means real networking work, not
# just a data-source lookup.
#
# This file creates routes inside coder-demo-eks's own route tables (found
# by tag, not by modifying that repo's Terraform) — so its blast radius
# crosses repo boundaries. Review the plan for the `aws.platform`-provider
# resources carefully before applying; they touch live, shared infrastructure.

provider "aws" {
  alias  = "platform"
  region = "eu-west-1"
}

data "aws_vpc" "platform" {
  provider = aws.platform
  id       = data.terraform_remote_state.platform.outputs.vpc_id
}

data "aws_route_table" "platform_public" {
  provider = aws.platform
  vpc_id   = data.aws_vpc.platform.id

  filter {
    name   = "tag:Name"
    values = ["coder-demo-vpc-public"]
  }
}

data "aws_route_table" "platform_private" {
  provider = aws.platform
  vpc_id   = data.aws_vpc.platform.id

  filter {
    name   = "tag:Name"
    values = ["coder-demo-vpc-private"]
  }
}

resource "aws_vpc_peering_connection" "to_platform" {
  vpc_id      = aws_vpc.main.id
  peer_vpc_id = data.aws_vpc.platform.id
  peer_region = "eu-west-1"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-to-platform"
  })
}

# Accepter lives in the platform's region/account — same account here, so
# auto_accept works without a manual approval step.
resource "aws_vpc_peering_connection_accepter" "platform" {
  provider                  = aws.platform
  vpc_peering_connection_id = aws_vpc_peering_connection.to_platform.id
  auto_accept               = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-to-platform-accepter"
  })
}

# ── Routes: this cluster's side ────────────────────────────────────────────────

resource "aws_route" "public_to_platform" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = data.aws_vpc.platform.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.to_platform.id
}

resource "aws_route" "private_to_platform" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = data.aws_vpc.platform.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.to_platform.id
}

# ── Routes: the platform's side ────────────────────────────────────────────────
# Additive only — one new route each, nothing else about these route tables
# is touched or managed by this state.

resource "aws_route" "platform_public_to_team" {
  provider                  = aws.platform
  route_table_id            = data.aws_route_table.platform_public.id
  destination_cidr_block    = aws_vpc.main.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.to_platform.id

  depends_on = [aws_vpc_peering_connection_accepter.platform]
}

resource "aws_route" "platform_private_to_team" {
  provider                  = aws.platform
  route_table_id            = data.aws_route_table.platform_private.id
  destination_cidr_block    = aws_vpc.main.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.to_platform.id

  depends_on = [aws_vpc_peering_connection_accepter.platform]
}

# ── Security group rule: allow this cluster to reach the NLB's listener ──────
# Found by the AWS Load Balancer Controller's own tags rather than a literal
# ID, since it doesn't come from a Terraform output — it's a resource that
# repo's Terraform doesn't manage directly (the controller does).
data "aws_security_group" "platform_nlb" {
  provider = aws.platform

  filter {
    name   = "tag:elbv2.k8s.aws/cluster"
    values = ["coder-demo-eks"]
  }
  filter {
    name   = "tag:service.k8s.aws/resource"
    values = ["ManagedLBSecurityGroup"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "platform_nlb_from_team" {
  provider          = aws.platform
  security_group_id = data.aws_security_group.platform_nlb.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = aws_vpc.main.cidr_block
  description       = "coder-team-demo-eks - external provisioner"
}
