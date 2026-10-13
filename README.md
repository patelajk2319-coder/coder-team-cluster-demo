# coder-team-cluster-demo

A team-owned EKS cluster that runs Coder workspace pods, registered against
an external Coder control plane via an external provisioner. Governance —
templates, audit log, AI Bridge policy, SSO — stays on the control plane;
this cluster only ever runs workspace pods for builds tagged to it.

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

## Prerequisites

This cluster is independent, but it needs to connect back to a Coder
control plane to register its provisioner. Get these from that control
plane's platform team and fill them into `.env` (see `.env.example`):

- `PLATFORM_REGION`, `PLATFORM_VPC_NAME`, `PLATFORM_CLUSTER_NAME` — its
  infrastructure, for the VPC peering
- `CODER_URL` — its Coder URL
- `CODER_PROVISIONER_KEY` — a provisioner key scoped to this cluster
  (minted on the control plane, not here)

`AWS_PROFILE` is yours to set. `TEAM_CLUSTER_NAME` is written by `task
cluster` — leave blank.

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
