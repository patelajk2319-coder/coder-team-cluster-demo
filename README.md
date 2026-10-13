# coder-team-cluster-demo

A team-owned EKS cluster that runs Coder workspace pods, registered against
an external Coder control plane via an external provisioner. Governance —
templates, audit log, AI Bridge policy, SSO — stays on the control plane;
this cluster only ever runs workspace pods for builds tagged to it.

## Prerequisites

### AWS Requirements
- Active AWS account — same account as the control plane (the peering
  accepter auto-accepts without a manual approval step)
- AWS CLI configured — either an SSO profile (`AWS_PROFILE=<profile>` in
  `.env`; `task login` opens the browser and authenticates automatically)
  or static credentials
- Admin-level IAM permissions to create VPC, EKS, and CloudWatch resources,
  plus permission to modify the control plane's route tables and NLB
  security group (cross-region peering touches both sides)

### Control Plane
This cluster is independent, but it needs to connect back to a Coder
control plane to register its provisioner. Get these from that control
plane's platform team:
- its region, VPC name, and EKS cluster name, for the VPC peering
- its Coder URL
- a provisioner key scoped to this cluster (minted on the control plane,
  not here)

### Required Tools (install via Homebrew)
```bash
brew install terraform awscli kubectl go-task shellcheck
```

## Configuration

Copy `.env.example` to `.env`.

**You fill in:**

| Variable Name | Description |
|----------------|-------------|
| `AWS_PROFILE` | Your AWS CLI profile |
| `PLATFORM_REGION` | Control plane's AWS region |
| `PLATFORM_VPC_NAME` | Control plane's VPC name |
| `PLATFORM_CLUSTER_NAME` | Control plane's EKS cluster name |
| `CODER_URL` | Control plane's Coder URL |
| `CODER_PROVISIONER_KEY` | Provisioner key minted by the control plane |

**Written by the deploy scripts — leave blank:**

| Variable Name | Description |
|----------------|-------------|
| `TEAM_CLUSTER_NAME` | This cluster's EKS cluster name — written by `task cluster` |

## Topology

Own region and VPC (`10.1.0.0/16`), connected to the control plane by
cross-region VPC peering, not shared networking (`terraform/cluster/peering.tf`).

Two Terraform directories:
- **`terraform/cluster`** — VPC, EKS, CloudWatch logs, the peering connection.
- **`terraform/provisioner`** — EBS CSI driver, `gp3` StorageClass, and the
  Coder provisioner (official `coder-provisioner` Helm chart).

## Node Pools

Three dedicated EKS node pools (`terraform/cluster/eks.tf`), each labeled
*and* tainted so nothing lands there without a matching `nodeSelector` +
toleration:

| Pool | Runs | Instance type |
|------|------|----------------|
| `system` | EBS CSI driver controller | `m6i.large` |
| `provisioner` | The Coder provisioner daemon | `m6i.large` |
| `workspaces` | Workspace pods | `m6i.2xlarge` |

Per-node DaemonSets (vpc-cni, kube-proxy, the EBS CSI node plugin) tolerate
all taints by default. Any template routed here needs a matching
`nodeSelector`/`tolerations` to land on `workspaces`.

## Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/patelajk2319-coder/coder-team-cluster-demo.git
cd coder-team-cluster-demo
```

### 2. Create `.env` File
```bash
cp .env.example .env
```

Fill in the values described in [Configuration](#configuration) above.

### 3. Deploy the Cluster
```bash
task login  # Validate AWS credentials
task up     # cluster, then provisioner
```

### 4. Confirm Registration

On the control plane: `coder provisioner list` should show this cluster's
provisioner.

## Cleanup

```bash
# Destroy this cluster (control plane untouched)
task nuke
```

## Available Commands

| Task | Description |
|------|-------------|
| `task login` | Validate AWS credentials |
| `task up` | Full deploy — `cluster` then `provisioner`, in order |
| `task cluster` | Deploy the EKS cluster (VPC, EKS, logs, peering) |
| `task provisioner` | Deploy the EBS CSI driver, `gp3` StorageClass, and the provisioner |
| `task nuke` | Destroy this cluster |
| `task validate` | `terraform fmt`/`validate` (both directories) + shellcheck |
| `task help` | List all available tasks |
