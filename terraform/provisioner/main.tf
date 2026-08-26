# ── EBS CSI Driver ──────────────────────────────────────────────────────────────
# Provides dynamic PersistentVolume provisioning for workspace home directories —
# adapted from coder-demo-eks/terraform/addons/modules/addons — same shape,
# scoped to this cluster's own OIDC provider.

data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.terraform_remote_state.cluster.outputs.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${data.terraform_remote_state.cluster.outputs.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${data.terraform_remote_state.cluster.outputs.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${data.terraform_remote_state.cluster.outputs.cluster_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = data.terraform_remote_state.cluster.outputs.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn
  tags                     = var.tags

  depends_on = [aws_iam_role_policy_attachment.ebs_csi]
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
# Registers with the control-plane coderd (coder-demo-eks) over an
# outbound-only connection — coderd never dials into this cluster. The
# provisioner tag that routes workspace builds here is baked into the key
# itself at creation time (coder provisioner keys create --tag ...), not
# configured here.

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
# Same shape as coder-demo-eks/terraform/coder's coder_workspace_provisioner
# ClusterRole, bound to this cluster's own provisioner service account
# instead of coderd's — the chart creates a service account named after the
# release ("coder-provisioner") in its own namespace, and it starts with no
# permissions beyond what the chart itself grants.

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
  # that's mostly idle between builds, and too big to fit two of these
  # m6i.large nodes at once alongside everything else already running.
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

  wait    = true
  timeout = 300
}
