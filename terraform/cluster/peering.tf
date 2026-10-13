# VPC peering back to the control plane, so the provisioner can reach its
# NLB. Touches its live route tables/SG (found by tag) — review before applying.

provider "aws" {
  alias  = "platform"
  region = var.platform_region
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
    values = ["${var.platform_vpc_name}-public"]
  }
}

data "aws_route_table" "platform_private" {
  provider = aws.platform
  vpc_id   = data.aws_vpc.platform.id

  filter {
    name   = "tag:Name"
    values = ["${var.platform_vpc_name}-private"]
  }
}

resource "aws_vpc_peering_connection" "to_platform" {
  vpc_id      = module.vpc.vpc_id
  peer_vpc_id = data.aws_vpc.platform.id
  peer_region = var.platform_region

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
  route_table_id            = module.vpc.public_route_table_ids[0]
  destination_cidr_block    = data.aws_vpc.platform.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.to_platform.id
}

resource "aws_route" "private_to_platform" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = data.aws_vpc.platform.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.to_platform.id
}

# ── Routes: the platform's side — additive only, one route each ───────────────

resource "aws_route" "platform_public_to_team" {
  provider                  = aws.platform
  route_table_id            = data.aws_route_table.platform_public.id
  destination_cidr_block    = module.vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.to_platform.id

  depends_on = [aws_vpc_peering_connection_accepter.platform]
}

resource "aws_route" "platform_private_to_team" {
  provider                  = aws.platform
  route_table_id            = data.aws_route_table.platform_private.id
  destination_cidr_block    = module.vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.to_platform.id

  depends_on = [aws_vpc_peering_connection_accepter.platform]
}

# ── Security group rule: allow this cluster to reach the NLB's listener ──────
# Found by tag, not a Terraform output — the LB controller owns this SG.
data "aws_security_group" "platform_nlb" {
  provider = aws.platform

  filter {
    name   = "tag:elbv2.k8s.aws/cluster"
    values = [var.platform_cluster_name]
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
  cidr_ipv4         = module.vpc.vpc_cidr_block
  description       = "coder-team-demo-eks - external provisioner"
}
