#!/usr/bin/env bash
# Destroy this team cluster and its provisioner — leaves the control plane
# (coder-demo-eks) untouched. Remember to also delete the provisioner key on
# the control plane (coder provisioner keys delete) once this is torn down.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CLUSTER_TF_DIR="${ROOT_DIR}/terraform/cluster"
PROVISIONER_TF_DIR="${ROOT_DIR}/terraform/provisioner"

# shellcheck source=scripts/lib/colors.sh
source "${SCRIPT_DIR}/../lib/colors.sh"

if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  error ".env not found"
  exit 1
fi
# shellcheck source=/dev/null
set -a; source "${ROOT_DIR}/.env"; set +a

# Destroy the provisioner first, while the cluster it's deployed onto still
# exists — the kubernetes/helm providers here are configured against it.
if [[ -f "${PROVISIONER_TF_DIR}/terraform.tfstate" ]]; then
  section "Destroying provisioner, EBS CSI driver, and gp3 StorageClass..."
  terraform -chdir="${PROVISIONER_TF_DIR}" destroy -auto-approve \
    -var="coder_url=${CODER_URL:-http://placeholder}" \
    -var="coder_provisioner_key=${CODER_PROVISIONER_KEY:-placeholder}" \
    || warn "Destroying terraform/provisioner failed — some resources may require manual cleanup"
fi

section "Destroying VPC subnets, EKS cluster, and CloudWatch logs..."
terraform -chdir="${CLUSTER_TF_DIR}" destroy -auto-approve \
  || warn "Destroying terraform/cluster failed — some resources may require manual cleanup"

section "Clearing local terraform/provisioner state..."
rm -f "${PROVISIONER_TF_DIR}"/terraform.tfstate "${PROVISIONER_TF_DIR}"/terraform.tfstate.backup

info "Team cluster destroyed"
info "Remember to delete the provisioner key on the control plane too"
