# Exposes /dev/fuse to pods on the workspaces node pool as a proper,
# kubelet-accounted extended resource (smarter-devices/fuse) — not a
# hostPath bypass. Needed for rootless Podman's fuse-overlayfs storage
# driver in coder-template-api-python-podman, which requests this
# resource explicitly rather than mounting the host device directly.
#
# smarter-device-manager: https://github.com/smarter-project/smarter-device-manager
# Pinned to its latest tagged release as of 2026-11-02.

resource "kubernetes_namespace" "smarter_device_manager" {
  metadata {
    name = "smarter-device-manager"
  }
}

resource "kubernetes_config_map_v1" "smarter_device_manager" {
  metadata {
    name      = "smarter-device-manager-fuse"
    namespace = kubernetes_namespace.smarter_device_manager.metadata[0].name
  }

  data = {
    "conf.yaml" = yamlencode([
      { devicematch = "^fuse$", nummaxdevices = 20 }
    ])
  }
}

resource "kubernetes_daemon_set_v1" "smarter_device_manager" {
  metadata {
    name      = "smarter-device-manager"
    namespace = kubernetes_namespace.smarter_device_manager.metadata[0].name
    labels = {
      name = "smarter-device-manager"
      role = "agent"
    }
  }

  spec {
    selector {
      match_labels = {
        name = "smarter-device-manager"
      }
    }

    strategy {
      type = "RollingUpdate"
    }

    template {
      metadata {
        labels = {
          name = "smarter-device-manager"
        }
      }

      spec {
        # Our own existing node-pool label/taint, not the project's
        # suggested "smarter-device-manager=enabled" — one labeling
        # scheme, not two.
        node_selector = {
          "coder.com/node-pool" = "workspaces"
        }

        toleration {
          key      = "coder.com/node-pool"
          operator = "Equal"
          value    = "workspaces"
          effect   = "NoSchedule"
        }

        priority_class_name = "system-node-critical"
        host_network        = true
        dns_policy          = "ClusterFirstWithHostNet"

        container {
          name              = "smarter-device-manager"
          image             = "ghcr.io/smarter-project/smarter-device-manager:v1.20.12"
          image_pull_policy = "IfNotPresent"

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "15Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "15Mi"
            }
          }

          volume_mount {
            name       = "device-plugin"
            mount_path = "/var/lib/kubelet/device-plugins"
          }
          volume_mount {
            name       = "dev-dir"
            mount_path = "/dev"
          }
          volume_mount {
            name       = "sys-dir"
            mount_path = "/sys"
          }
          volume_mount {
            name       = "config"
            mount_path = "/root/config"
          }
        }

        volume {
          name = "device-plugin"
          host_path {
            path = "/var/lib/kubelet/device-plugins"
          }
        }
        volume {
          name = "dev-dir"
          host_path {
            path = "/dev"
          }
        }
        volume {
          name = "sys-dir"
          host_path {
            path = "/sys"
          }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.smarter_device_manager.metadata[0].name
          }
        }

        termination_grace_period_seconds = 30
      }
    }
  }
}
