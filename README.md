# coder-team-cluster-demo

A team-owned EKS cluster that runs Coder workspace pods, registered against
an external Coder control plane via an external provisioner. Governance —
templates, audit log, AI Bridge policy, SSO — stays on the control plane;
this cluster only ever runs workspace pods for builds tagged to it.

## Topology

Its own region and VPC (`10.1.0.0/16`), connected back to the control
plane by cross-region VPC peering rather than shared networking — real
isolation, real trade-off: its own VPC/IGW/NAT, and the peering connection
touches the control plane's route tables (additively, found by tag) and
adds a scoped ingress rule to its NLB security group (port 80 only,
CIDR-restricted to this cluster). See `terraform/cluster/peering.tf`.

Two Terraform directories, same `core-infra`/`addons` split reasoning as
most Coder-on-EKS platform repos:

- **`terraform/cluster`** — VPC, EKS, CloudWatch logs, the peering
  connection. Pure AWS, no kubernetes/helm provider — can't configure one
  against a cluster that doesn't exist yet. VPC and EKS are
  `terraform-aws-modules/*` registry modules, not hand-rolled.
- **`terraform/provisioner`** — EBS CSI driver + `gp3` StorageClass, and the
  Coder provisioner itself (official `coder-provisioner` Helm chart). Reads
  `terraform/cluster`'s state via `terraform_remote_state`. The EBS CSI
  IRSA role is the `terraform-aws-modules/iam` registry submodule too.

## Node Pools

Three dedicated EKS node pools (`terraform/cluster/eks.tf`), each labeled
*and* tainted so nothing lands there without a matching `nodeSelector` +
toleration: isolate unpredictable/user-driven workloads (workspace pods)
from infrastructure, and infrastructure components from each other by what
manages them.

| Pool | Runs | Instance type |
|------|------|----------------|
| `system` | EBS CSI driver controller (AWS/EKS infra) | `m6i.large` |
| `provisioner` | The Coder provisioner daemon only | `m6i.large` |
| `workspaces` | Actual workspace pods | `m6i.2xlarge` |

Per-node DaemonSets that must run everywhere regardless of pool (vpc-cni,
kube-proxy, the EBS CSI node plugin) are untouched — they tolerate all
taints by default.

`workspaces` isn't deferred — this cluster's whole purpose is running
workspace pods, so every build routed here needs a matching
`nodeSelector`/`tolerations` on the template side (see
`coder-template-api-python`'s `kubernetes_pod.workspace` for an example).

`workspaces` nodes are sized for a full small/medium/large workspace range
(large alone requests 4 vCPU plus the `dind` sidecar's 250m) — a hard
per-node ceiling, since Kubernetes never splits one pod across nodes.

## Prerequisites

Everything below describes the Coder control plane you're pairing this
cluster with — ask its platform team for these values, then fill them into
`.env` (see `.env.example`):

- `PLATFORM_STATE_PATH`, `PLATFORM_REGION`, `PLATFORM_VPC_NAME`,
  `PLATFORM_CLUSTER_NAME` — identify its infrastructure for the VPC
  peering in `terraform/cluster/peering.tf`.
- `CODER_URL` — its Coder URL.
- `CODER_PROVISIONER_KEY` — a provisioner key minted by its platform team
  (via the `coderd_provisioner_key` Terraform resource) — this repo
  doesn't create its own key; that's a control-plane governance action.

Also needed locally: `terraform`, `awscli`, `kubectl`, `go-task`, `shellcheck`.

## Quick start

```bash
cp .env.example .env   # fill in the prerequisites above

task login
task up   # cluster, then provisioner
```

Confirm it registered from the control plane: `coder provisioner list`.

## Commands

| Command           | Description                                                        |
|-------------------|----------------------------------------------------------------------|
| `task login`      | Validate AWS credentials                                              |
| `task cluster`    | Deploy the EKS cluster (subnets, EKS, logs)                            |
| `task provisioner`| Deploy the EBS CSI driver, `gp3` StorageClass, and the provisioner     |
| `task up`         | Both of the above, in order                                            |
| `task validate`   | `terraform fmt`/`validate` for both directories, plus shellcheck       |
| `task nuke`       | Destroy this cluster (control plane untouched)                        |
