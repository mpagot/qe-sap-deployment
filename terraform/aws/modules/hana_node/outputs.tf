data "aws_instance" "hana" {
  count       = var.hana_count
  instance_id = element(aws_instance.hana.*.id, count.index)
}

output "hana_ip" {
  value = data.aws_instance.hana.*.private_ip
}

output "hana_public_ip" {
  value = data.aws_instance.hana.*.public_ip
}

output "hana_name" {
  value = data.aws_instance.hana.*.id
}

output "hana_name_ebs_devices_id" {
  value = flatten([for instance in data.aws_instance.hana : [for device in instance.ebs_block_device : device.volume_id]])
}

#output "hana_name_ebs_devices_tags" {
#  value = flatten([for instance in data.aws_instance.hana : [for device in instance.ebs_block_device : device.tags_all]])
#}

#output "hana_name_root_device_volume_id" {
#  value = data.aws_instance.hana.*.root_block_device.volume_id
#}

output "hana_public_name" {
  value = data.aws_instance.hana.*.public_dns
}

output "stonith_tag" {
  value = local.hana_stonith_tag
}

