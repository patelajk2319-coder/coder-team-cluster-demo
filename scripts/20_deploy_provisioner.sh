#!/usr/bin/env bash
# Deploy the EBS CSI driver + gp3 StorageClass and the Coder external
# provisioner — terraform/provisioner, needs the cluster from `task cluster`
# to already exist.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform/provisioner"

# shellcheck source=scripts/lib/colors.sh
source "${SCRIPT_DIR}/lib/colors.sh"

if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  error ".env not found — copy .env.example and fill in values"
  exit 1
fi
# shellcheck source=/dev/null
set -a; source "${ROOT_DIR}/.env"; set +a

: "${CODER_URL:?CODER_URL must be set in .env}"
: "${CODER_PROVISIONER_KEY:?CODER_PROVISIONER_KEY must be set in .env — ask the platform team to mint one}"
: "${TEAM_CLUSTER_NAME:?TEAM_CLUSTER_NAME must be set in .env — run task cluster first}"

section "Initialising Terraform (terraform/provisioner)..."
terraform -chdir="${TF_DIR}" init -upgrade

section "Deploying EBS CSI driver, gp3 StorageClass, and Coder provisioner..."
terraform -chdir="${TF_DIR}" apply \
  -var="coder_url=${CODER_URL}" \
  -var="coder_provisioner_key=${CODER_PROVISIONER_KEY}" \
  -auto-approve

echo ""
info "Provisioner deployed"
info "Confirm it registered: coder provisioner list (on the control plane)"
