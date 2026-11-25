# Bluefin Server on Akamai/Linode.
#
# The instance is created without an image; the disk is written from the
# uploaded private image and booted directly (linode/direct-disk, all helpers
# off) so Linode never touches the UKI/systemd-boot setup. The Ignition config
# travels in metadata.user_data; the node reads it from the Metadata service.

resource "random_password" "root" {
  length  = 32
  special = true
}

resource "linode_instance" "this" {
  label      = var.label
  region     = var.region
  type       = var.instance_type
  tags       = var.tags
  private_ip = var.private_ip

  metadata {
    user_data = base64encode(file(var.ignition_path))
  }
}

resource "linode_instance_disk" "boot" {
  label     = "${var.label}-boot"
  linode_id = linode_instance.this.id
  size      = var.boot_disk_mb

  image      = var.image_id
  root_pass  = random_password.root.result
  filesystem = "raw"
}

# Second disk for a persistent /var; the state-disk overlay makes Ignition format it.
# Known at plan time (unlike the instance's specs), so it can drive count.
data "linode_instance_type" "this" {
  id = var.instance_type
}

locals {
  state_disk_mb = coalesce(var.state_disk_mb, data.linode_instance_type.this.disk - var.boot_disk_mb)
}

resource "linode_instance_disk" "state" {
  count      = local.state_disk_mb > 0 ? 1 : 0
  label      = "${var.label}-state"
  linode_id  = linode_instance.this.id
  size       = local.state_disk_mb
  filesystem = "raw"
}

resource "linode_instance_config" "this" {
  label     = "${var.label}-config"
  linode_id = linode_instance.this.id

  device {
    device_name = "sda"
    disk_id     = linode_instance_disk.boot.id
  }

  dynamic "device" {
    for_each = linode_instance_disk.state
    content {
      device_name = "sdb"
      disk_id     = device.value.id
    }
  }

  kernel      = "linode/direct-disk"
  root_device = "/dev/sda"

  helpers {
    distro             = false
    network            = false
    modules_dep        = false
    devtmpfs_automount = false
    updatedb_disabled  = true
  }

  booted = true
}
