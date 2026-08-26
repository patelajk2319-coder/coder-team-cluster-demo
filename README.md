# coder-team-cluster-demo

A team-owned EKS cluster that runs Coder workspace pods, registered against
the control plane in [coder-demo-eks](https://github.com/patelajk2319-coder/coder-demo-eks)
via an external provisioner. Governance — templates, audit log, AI Bridge
policy, SSO — stays on the control plane; this cluster only ever runs
workspace pods for builds tagged to it.

## Topology

A genuinely separate region from `coder-demo-eks` (`eu-west-2` vs. its
`eu-west-1`) — its own VPC (`10.1.0.0/16`), connected back to the control
plane by cross-region VPC peering rather than shared networking. Real
isolation, real trade-off: this needed its own VPC/IGW/NAT (not just new
subnets in an existing VPC), and the peering connection touches
`coder-demo-eks`'s route tables — additively, found by tag rather than by
editing that repo's Terraform, but it's still a change to shared,
live infrastructure. See `terraform/cluster/peering.tf`.

**Known gap, not yet wired:** peering makes the two VPCs routable to each
other, but the EKS cluster security group in `coder-demo-eks` doesn't yet
allow inbound traffic from this cluster's CIDR — routes alone don't open
anything. That's a deliberate follow-up, not an oversight: it's a security
posture change to the live control plane and shouldn't happen without an
explicit decision on scope (allow only the provisioner's actual port, not a
broad rule).

Two Terraform directories, same reasoning as `coder-demo-eks`'s
`core-infra`/`addons` split:

- **`terraform/cluster`** — VPC, EKS, CloudWatch logs, the peering connection.
  Pure AWS, no kubernetes/helm provider — can't configure one against a
  cluster that doesn't exist yet in the same apply.
- **`terraform/provisioner`** — EBS CSI driver + `gp3` StorageClass, and the
  Coder provisioner itself (official `coder-provisioner` Helm chart). Reads
  `terraform/cluster`'s state via `terraform_remote_state`.

## Prerequisites

- `coder-demo-eks` deployed and reachable.
- A provisioner key minted by whoever administers that control plane
  (`coder provisioner keys create <name> --tag team=<name>` — this repo
  doesn't create its own key; that's a control-plane governance action).
- `terraform`, `awscli`, `kubectl`, `go-task` installed locally.

## Quick start

```bash
cp .env.example .env   # fill in CODER_URL, CODER_PROVISIONER_KEY

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
| `task validate`   | `terraform fmt`/`validate` for both directories                        |
| `task nuke`       | Destroy this cluster (control plane untouched)                        |
