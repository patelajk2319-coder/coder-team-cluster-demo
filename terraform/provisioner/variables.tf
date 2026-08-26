# Minted on the control plane (coder-demo-eks) by a platform admin — this
# team never gets broader Coder credentials than this one scoped key.
# See coder-demo-eks/scripts/tools/create_provisioner_key.sh.
variable "coder_provisioner_key" {
  description = "Provisioner key issued by the control-plane Coder instance"
  type        = string
  sensitive   = true
}

variable "coder_url" {
  description = "Control-plane Coder URL this provisioner registers against"
  type        = string
}

variable "provisioner_replicas" {
  description = "Number of provisioner daemon replicas (concurrent workspace builds)"
  type        = number
  default     = 1
}

# Must match the control plane's Coder version — the provisioner protocol
# isn't forward-compatible (a newer daemon can speak a protocol version the
# server doesn't understand yet, and registration fails outright rather than
# just warning).
variable "coder_version" {
  description = "coder-provisioner chart version — must match the control plane's Coder version"
  type        = string
  default     = "2.33.6"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    project     = "coder-team-demo"
    managed-by  = "terraform"
    environment = "demo"
  }
}
