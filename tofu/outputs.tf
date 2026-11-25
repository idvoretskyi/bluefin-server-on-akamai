data "linode_instance_networking" "this" {
  linode_id = linode_instance.this.id
}

output "instance_id" {
  value = linode_instance.this.id
}

output "ip_address" {
  value = try(data.linode_instance_networking.this.ipv4[0].public[0].address, null)
}

output "ssh_command" {
  value = "ssh root@${try(data.linode_instance_networking.this.ipv4[0].public[0].address, "<ip>")}"
}
