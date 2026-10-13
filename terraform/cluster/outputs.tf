output "cluster_name" {
  description = "Name of this EKS cluster"
  value       = module.eks.cluster_name
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider — used for IRSA role trust policies"
  value       = module.eks.oidc_provider_arn
}
