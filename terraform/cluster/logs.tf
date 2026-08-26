# EKS control-plane logging writes to a fixed log group name
# (/aws/eks/<cluster>/cluster). Pre-creating it here lets us control retention —
# otherwise EKS creates it on first log write with logs kept indefinitely.
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${local.name_prefix}-eks/cluster"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}
