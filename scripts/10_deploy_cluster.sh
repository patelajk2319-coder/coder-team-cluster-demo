#!/usr/bin/env bash
# Deploy this team's own VPC, EKS cluster, CloudWatch logs, and the peering
# connection back to the platform VPC — terraform/cluster, pure AWS, no
# kubernetes/helm provider. Same reasoning as coder-demo-eks/terraform/core-infra:
# the cluster can't be a kubernetes/helm provider target in the same apply
# that creates it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform/cluster"

# shellcheck source=scripts/lib/colors.sh
source "${SCRIPT_DIR}/lib/colors.sh"

if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  error ".env not found — copy .env.example and fill in values"
  exit 1
fi
set -a
# shellcheck source=/dev/null
source "${ROOT_DIR}/.env"
set +a

section "Initialising Terraform (terraform/cluster)..."
terraform -chdir="${TF_DIR}" init -upgrade

section "Deploying VPC subnets, EKS cluster, and CloudWatch logs..."
terraform -chdir="${TF_DIR}" apply -auto-approve

CLUSTER_NAME=$(terraform -chdir="${TF_DIR}" output -raw cluster_name)

section "Writing kubeconfig..."
# --region is required here — this cluster is deliberately not in the AWS
# CLI/profile's default region (coder-demo-eks's eu-west-1).
aws eks update-kubeconfig \
  --name "${CLUSTER_NAME}" \
  --region eu-west-2 \
  --alias "${CLUSTER_NAME}-admin"

info "EKS context '${CLUSTER_NAME}-admin' written to kubeconfig"

section "Verifying cluster connectivity..."
if ! kubectl wait --for=condition=Ready node --all --timeout=120s; then
  error "Nodes did not reach Ready — check 'kubectl get nodes' before retrying"
  exit 1
fi
kubectl get nodes

section "Updating .env with cluster name..."
if grep -q "^TEAM_CLUSTER_NAME=" "${ROOT_DIR}/.env"; then
  sed -i '' "s|^TEAM_CLUSTER_NAME=.*|TEAM_CLUSTER_NAME=${CLUSTER_NAME}|" "${ROOT_DIR}/.env"
else
  echo "TEAM_CLUSTER_NAME=${CLUSTER_NAME}" >> "${ROOT_DIR}/.env"
fi

echo ""
info "Cluster is ready"
info "Run: task provisioner"
