data "aws_ami" "this" {
  count = (
    contains(keys(local.default_images), var.config.image_id) ||
    can(var.config.custom_image_id_source)
  ) ? 1 : 0

  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name = "name"
    values = try(
      local.default_images[var.config.image_id].filter_image_names,
      var.config.custom_image_id_source.filter_image_names
    )
  }

  owners = try(
    local.default_images[var.config.image_id].owners,
    var.config.custom_image_id_source.owners
  )
}

data "aws_key_pair" "this" {
  count = (
    try(var.config.keypair_public_key, null) != null ? (
      fileexists(var.config.keypair_public_key) ?
      file(var.config.keypair_public_key) : null
    ) : null
  ) == null ? 1 : 0

  key_name           = var.config.keypair_name
  include_public_key = true
}

resource "aws_key_pair" "this" {
  count = (
    try(var.config.keypair_public_key, null) != null ? (
      fileexists(var.config.keypair_public_key) ?
      file(var.config.keypair_public_key) : null
    ) : null
  ) != null ? 1 : 0

  key_name   = var.config.keypair_name
  public_key = file(var.config.keypair_public_key)

  tags = {
    Name = var.config.keypair_name
  }
}

resource "aws_instance" "nodes" {
  for_each = local.inframap_nodes

  ami = (
    contains(keys(local.default_images), each.value.image_id) ||
    can(var.config.custom_image_id_source)
  ) ? data.aws_ami.this[0].id : each.value.image_id
  instance_type = each.value.instance_type
  vpc_security_group_ids = [
    aws_vpc.this.default_security_group_id,
    aws_security_group.sgs[each.value.node_type].id
  ]
  subnet_id                   = aws_subnet.subnets[substr(each.value.availability_zone, -1, -1)].id
  associate_public_ip_address = true
  availability_zone           = each.value.availability_zone
  key_name                    = var.config.keypair_name

  user_data = templatefile(
    "${path.module}/templates/init.sh.tpl",
    {
      username        = var.config.ec2_username
      ebs_device_name = try(each.value.volumes.data.device_name_template, "")
      ansible_public_key = try(
        data.aws_key_pair.this[0].public_key,
        aws_key_pair.this[0].public_key
      )
      engineer_public_key = try(
        data.aws_key_pair.this[0].public_key,
        aws_key_pair.this[0].public_key
      )
      hostname = replace(each.key, "_", "-")
    }
  )

  root_block_device {
    volume_type = each.value.volumes.root.type
    volume_size = each.value.volumes.root.size
    iops = (
      contains(["io1", "io2", "gp3"], each.value.volumes.root.type)
    ) ? each.value.volumes.root.iops : null
    throughput = (
      contains(["gp3"], each.value.volumes.root.type)
    ) ? each.value.volumes.root.throughput : null

    tags = {
      Name = "${title(each.value.instance_name)} - Root"
    }
  }

  tags = {
    Name = title(each.value.instance_name)
  }

  lifecycle {
    ignore_changes = [
      ami,
    ]
  }
}

resource "aws_ebs_volume" "data_volumes" {
  for_each = { for node, node_config in local.inframap_nodes :
    node => {
      size = node_config.volumes.data.size
      type = node_config.volumes.data.type
      iops = (
        contains(["io1", "io2", "gp3"], node_config.volumes.data.type)
      ) ? node_config.volumes.data.iops : null
      throughput = (
        contains(["gp3"], node_config.volumes.data.type)
      ) ? node_config.volumes.data.throughput : null
      availability_zone = node_config.availability_zone
      name              = node_config.instance_name
    } if can(node_config.volumes.data)
  }

  size              = each.value.size
  type              = each.value.type
  iops              = each.value.iops
  throughput        = each.value.throughput
  availability_zone = each.value.availability_zone

  tags = {
    Name = "${title(each.value.name)} - Data"
  }
}

resource "aws_volume_attachment" "data_volume_attachments" {
  for_each = { for node, node_config in local.inframap_nodes :
    node => {
      device_name = node_config.volumes.data.device_name
    } if can(node_config.volumes.data)
  }
  device_name  = each.value.device_name
  force_detach = true
  volume_id    = aws_ebs_volume.data_volumes[each.key].id
  instance_id  = aws_instance.nodes[each.key].id

  lifecycle {
    ignore_changes = [
      device_name,
    ]
  }
}

resource "aws_eip" "eips" {
  for_each = local.inframap_nodes

  instance = aws_instance.nodes[each.key].id
  vpc      = true
}
