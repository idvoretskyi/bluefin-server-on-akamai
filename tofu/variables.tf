variable "image_id" {
  description = "Private image id from scripts/upload-image.sh, e.g. \"private/1234567\"."
  type        = string

  validation {
    condition     = can(regex("^private/[0-9]+$", var.image_id))
    error_message = "image_id must look like \"private/<number>\" (run scripts/upload-image.sh first)."
  }
}

variable "ignition_path" {
  description = "Rendered Ignition JSON (make ignition)."
  type        = string
  default     = "../build/ignition.json"
}

variable "region" {
  description = "Linode region; must match the image's region."
  type        = string
  default     = "us-ord"
}

variable "instance_type" {
  description = "Linode type. g6-standard-2 (4 GB) is a comfortable minimum."
  type        = string
  default     = "g6-standard-2"
}

variable "label" {
  type    = string
  default = "bluefin-akamai"
}

variable "tags" {
  type    = list(string)
  default = ["bluefin-server", "managed-by-opentofu"]
}

variable "private_ip" {
  type    = bool
  default = false
}

variable "state_disk_mb" {
  description = "Size of an optional second disk (sdb) for persistent /var; 0 disables it."
  type        = number
  default     = 0
}

variable "boot_disk_mb" {
  description = "Boot disk size in MB; null uses the plan's disk minus state_disk_mb."
  type        = number
  default     = null
}
