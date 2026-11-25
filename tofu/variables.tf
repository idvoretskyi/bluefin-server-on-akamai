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

variable "boot_disk_mb" {
  description = "Boot disk size in MB. The boot disk only holds the syslinux boot image (kernel + initrd), so it stays small."
  type        = number
  default     = 1024
}

variable "state_disk_mb" {
  description = "Size of the second disk (sdb, persistent /var); null uses the rest of the plan's disk, 0 disables it."
  type        = number
  default     = null
}
