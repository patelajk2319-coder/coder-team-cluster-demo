# Minted on the control plane via coderd_provisioner_key (task coder-config)
# — this team never gets broader Coder credentials than this one scoped key.
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

# Must match the control plane's Coder version — the build protocol isn't
# forward-compatible, so a mismatch fails registration outright.
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
