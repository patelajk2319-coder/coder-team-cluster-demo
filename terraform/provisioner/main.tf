# ── EBS CSI Driver ──────────────────────────────────────────────────────────────
# Registry IAM submodule, not a hand-written trust policy.

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name = "${data.terraform_remote_state.cluster.outputs.cluster_name}-ebs-csi"

  oidc_providers = {
    main = {
      provider_arn               = data.terraform_remote_state.cluster.outputs.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  attach_ebs_csi_policy = true

  tags = var.tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = data.terraform_remote_state.cluster.outputs.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.ebs_csi_irsa.arn
  tags                     = var.tags

  # Only the controller Deployment is pinned — the node plugin (a DaemonSet)
  # must keep running everywhere, workspaces pool included.
  configuration_values = jsonencode({
    controller = {
      nodeSelector = { "coder.com/node-pool" = "system" }
      tolerations = [
        { key = "CriticalAddonsOnly", operator = "Exists" },
        { operator = "Exists", effect = "NoExecute", tolerationSeconds = 300 },
        { key = "coder.com/node-pool", operator = "Equal", value = "system", effect = "NoSchedule" },
      ]
    }
  })
}

resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type = "gp3"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}

# ── Coder external provisioner ─────────────────────────────────────────────────
# Outbound-only connection to coderd — it never dials into this cluster.

resource "kubernetes_namespace" "coder_provisioner" {
  metadata {
    name = "coder-provisioner"
  }
}

resource "kubernetes_secret" "provisioner_key" {
  metadata {
    name      = "coder-provisioner-key"
    namespace = kubernetes_namespace.coder_provisioner.metadata[0].name
  }

  data = {
    key = var.coder_provisioner_key
  }
}

# ── Cluster-scoped RBAC for workspace provisioning ─────────────────────────────
# Bound to this cluster's own provisioner service account.

resource "kubernetes_cluster_role" "workspace_provisioner" {
  metadata {
    name = "coder-workspace-provisioner"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "persistentvolumeclaims"]
    verbs      = ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["networkpolicies"]
    verbs      = ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "workspace_provisioner" {
  metadata {
    name = "coder-workspace-provisioner"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.workspace_provisioner.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "coder-provisioner"
    namespace = kubernetes_namespace.coder_provisioner.metadata[0].name
  }
}

resource "helm_release" "provisioner" {
  name       = "coder-provisioner"
  repository = "https://helm.coder.com/v2"
  chart      = "coder-provisioner"
  version    = var.coder_version
  namespace  = kubernetes_namespace.coder_provisioner.metadata[0].name

  set {
    name  = "coder.env[0].name"
    value = "CODER_URL"
  }
  set {
    name  = "coder.env[0].value"
    value = var.coder_url
  }

  set {
    name  = "coder.replicaCount"
    value = var.provisioner_replicas
  }

  set {
    name  = "provisionerDaemon.keySecretName"
    value = kubernetes_secret.provisioner_key.metadata[0].name
  }
  set {
    name  = "provisionerDaemon.keySecretKey"
    value = "key"
  }

  # Chart default is 2 CPU / 4Gi per replica — real overkill for a daemon
  # that's mostly idle between builds.
  set {
    name  = "coder.resources.requests.cpu"
    value = "250m"
  }
  set {
    name  = "coder.resources.requests.memory"
    value = "512Mi"
  }
  set {
    name  = "coder.resources.limits.cpu"
    value = "1"
  }
  set {
    name  = "coder.resources.limits.memory"
    value = "1Gi"
  }

  # Pin to the dedicated provisioner node pool, isolated from both the
  # system pool and the workspace pods it builds.
  values = [
    yamlencode({
      coder = {
        nodeSelector = { "coder.com/node-pool" = "provisioner" }
        tolerations = [
          {
            key      = "coder.com/node-pool"
            operator = "Equal"
            value    = "provisioner"
            effect   = "NoSchedule"
          }
        ]
      }
    }),
  ]

  wait    = true
  timeout = 300
}
