resource "local_file" "ansible_inventory" {
  count = var.ansible_inventory.generate ? 1 : 0

  content = templatefile("${path.module}/templates/inventory.tpl",
    {
      nodes = { for node, node_config in var.config.nodes :
        node => { for index in range(1, node_config.count + 1) :
          "${node}_${index}" => {
            ip = aws_eip.eips["${node}_${index}"].public_ip
          }
        } if node_config.count > 0
      }
      admin_user                 = var.config.ec2_username
      path_to_ansible_public_key = replace(var.config.keypair_public_key, ".pub", "")
    }
  )
  filename = (try(var.ansible_inventory.output_file, null) != null ?
    var.ansible_inventory.output_file :
    abspath("${path.root}/../ansible/inventories/aws-${data.aws_region.this.name}.yml")
  )
  file_permission = "0644"
}
