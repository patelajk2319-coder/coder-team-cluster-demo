output "cluster_name" {
  description = "Name of this EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider — used for IRSA role trust policies"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "URL of the cluster's OIDC issuer, without the https:// prefix"
  value       = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}
