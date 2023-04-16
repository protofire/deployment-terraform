locals {
  default_nodes = {
    netstat = {
      instance_name = "Netstat"
      instance_type = "t3a.micro"
      volumes = {
        root = local.default_volumes.root
      }
      security_groups = {
        ssh = {
          port = 22
        }
      }
    }
    bootnode = {
      instance_name = "Bootnode"
      instance_type = "t3a.large"
      elb = {
        enabled = true
        port    = 80
      }
      volumes = {
        root = local.default_volumes.root
        data = local.default_volumes.data
      }
      security_groups = {
        ssh = {
          port = 22
        }
        http = {
          port                  = 80
          source_security_group = "bootnode_lb"
        }
        p2p = {
          port     = 30303
          protocol = "udp"
        }
      }
    }
    bridge = {
      instance_name = "Bridge Validator"
      instance_type = "t3a.micro"
      volumes = {
        root = local.default_volumes.root
        data = merge(local.default_volumes.data, { size = 32 })
      }
      security_groups = {
        ssh = {
          port = 22
        }
      }
    }
    validator = {
      instance_name = "Validator"
      instance_type = "t3a.micro"
      volumes = {
        root = local.default_volumes.root
        data = local.default_volumes.data
      }
      security_groups = {
        ssh = {
          port = 22
        }
        p2p = {
          port     = 30303
          protocol = "udp"
        }
      }
    }
    owner = {
      instance_name = "MoC"
      instance_type = "t3a.micro"
      volumes = {
        root = local.default_volumes.root
        data = local.default_volumes.data
      }
      security_groups = {
        ssh = {
          port = 22
        }
        p2p = {
          port     = 30303
          protocol = "udp"
        }
      }
    }
  }
  default_volumes = {
    root = {
      size       = 8
      type       = "gp3"
      iops       = 3000
      throughput = 125
    }
    data = {
      size                 = 50
      type                 = "gp3"
      iops                 = 3000
      throughput           = 125
      device_name          = "/dev/xvdh"
      device_name_template = "/dev/nvme1n1"
    }
  }
  default_security_groups = {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  default_images = {
    ubuntu = {
      filter_image_names = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
      owners             = ["099720109477"]
    }
  }
  enabled_availability_zones = tolist(setintersection(
    [for zone in data.aws_availability_zones.this.names : trimprefix(zone, data.aws_region.this.name)],
    var.config.availability_zones
  ))
  inframap_security_groups = { for node, node_config in var.config.nodes :
    node => {
      security_groups = merge({ for sg, sg_config in local.default_nodes[node].security_groups :
        sg => {
          port = (try(node_config.overwrite_defaults.security_groups[sg].port, null) != null ?
            node_config.overwrite_defaults.security_groups[sg].port : sg_config.port
          )
          protocol = try(sg_config.protocol, (
            try(node_config.overwrite_defaults.security_groups[sg].protocol, null) != null ?
            node_config.overwrite_defaults.security_groups[sg].protocol : try(
              sg_config.protocol, local.default_security_groups.protocol
          )))
          cidr_blocks = try(sg_config.cidr_blocks, (
            try(node_config.overwrite_defaults.security_groups[sg].cidr_blocks, null) != null ?
            node_config.overwrite_defaults.security_groups[sg].cidr_blocks : try(
              sg_config.cidr_blocks, local.default_security_groups.cidr_blocks
          )))
          source_security_group = try(sg_config.source_security_group, (
            try(node_config.overwrite_defaults.security_groups[sg].source_security_group, null) != null ?
            node_config.overwrite_defaults.security_groups[sg].source_security_group : try(
              sg_config.source_security_group, null
          )))
        }
        },
        { for sg, sg_config in node_config.overwrite_defaults.security_groups :
          sg => sg_config
        }
      )
    }
  }
  inframap_elb = {
    bootnode_lb = {
      enabled = anytrue([for index in range(1, try(var.config.nodes["bootnode"].count, 0) + 1) :
        try(var.config.nodes["bootnode"].overwrite_specific_node_index_config[index].elb.enabled, null) != null ?
        var.config.nodes["bootnode"].overwrite_specific_node_index_config[index].elb.enabled :
        (try(var.config.nodes["bootnode"].overwrite_defaults.elb.enabled, null) != null ?
          var.config.nodes["bootnode"].overwrite_defaults.elb.enabled : local.default_nodes["bootnode"].elb.enabled
        )
      ])
      port = try(var.config.nodes.bootnode.overwrite_defaults.elb.port,
        local.default_nodes.bootnode.elb.port
      )
      security_groups = {
        bootnode_lb = {
          port = try(var.config.nodes.bootnode.overwrite_defaults.elb.port,
            local.default_nodes.bootnode.elb.port
          )
          protocol = try(var.config.nodes.bootnode.overwrite_defaults.elb.protocol,
            local.default_security_groups.protocol
          )
          cidr_blocks = try(var.config.nodes.bootnode.overwrite_defaults.elb.cidr_blocks,
            local.default_security_groups.cidr_blocks
          )
        }
      }
    }
  }
  inframap_nodes = merge(flatten([for node, node_config in var.config.nodes :
    { for index in range(1, node_config.count + 1) :
      "${node}_${index}" => {
        node_type = node
        index     = index
        instance_name = (
          try(var.config.nodes[node].overwrite_specific_node_index_config[index].instance_name, null) != null ?
          var.config.nodes[node].overwrite_specific_node_index_config[index].instance_name :
          (try(node_config.overwrite_defaults.instance_name, null) != null ?
            "${node_config.overwrite_defaults.instance_name} - ${index}" :
            "${local.default_nodes[node].instance_name} - ${index}"
          )
        )
        instance_type = (
          try(var.config.nodes[node].overwrite_specific_node_index_config[index].instance_type, null) != null ?
          var.config.nodes[node].overwrite_specific_node_index_config[index].instance_type :
          (try(node_config.overwrite_defaults.instance_type, null) != null ?
            node_config.overwrite_defaults.instance_type : local.default_nodes[node].instance_type
          )
        )
        image_id = (
          try(var.config.nodes[node].overwrite_specific_node_index_config[index].image_id, null) != null ?
          var.config.nodes[node].overwrite_specific_node_index_config[index].image_id :
          (try(node_config.overwrite_defaults.image_id, null) != null ?
            node_config.overwrite_defaults.image_id : var.config.image_id
          )
        )
        availability_zone = "${data.aws_region.this.name}${
          contains(data.aws_availability_zones.this.names,
            "${data.aws_region.this.name}${var.config.availability_zones[
              (try(
                var.config.nodes["bootnode"].overwrite_specific_node_index_config[2].availability_zone, null) != null ?
                index(data.aws_availability_zones.this.names, "${data.aws_region.this.name}${
                  var.config.nodes["bootnode"].overwrite_specific_node_index_config[2].availability_zone
                  }") : (2 - 1
                )) % (length(data.aws_availability_zones.this.names) > length(var.config.availability_zones) ?
                length(var.config.availability_zones) : length(data.aws_availability_zones.this.names)
              )
            ]}"
          )
          ?
          local.enabled_availability_zones[
            (try(
              var.config.nodes["bootnode"].overwrite_specific_node_index_config[2].availability_zone, null) != null ?
              index(data.aws_availability_zones.this.names, "${data.aws_region.this.name}${
                var.config.nodes["bootnode"].overwrite_specific_node_index_config[2].availability_zone
                }") : (2 - 1
              )) % (length(data.aws_availability_zones.this.names) > length(var.config.availability_zones) ?
              length(local.enabled_availability_zones) : length(data.aws_availability_zones.this.names)
            )
          ]
          :
          local.enabled_availability_zones[
            (2 - 1) % length(data.aws_availability_zones.this.names)
          ]
        }"
        elb = node == "bootnode" ? {
          enabled = (
            try(var.config.nodes[node].overwrite_specific_node_index_config[index].elb.enabled, null) != null ?
            var.config.nodes[node].overwrite_specific_node_index_config[index].elb.enabled :
            (try(var.config.nodes[node].overwrite_defaults.elb.enabled, null) != null ?
              var.config.nodes[node].overwrite_defaults.elb.enabled : local.default_nodes[node].elb.enabled
            )
          )
        } : null
        volumes = { for volume, volume_config in local.default_nodes[node].volumes :
          volume => {
            size = (
              try(
                var.config.nodes[node].overwrite_specific_node_index_config[index].volumes[volume].size, null
              ) != null ?
              var.config.nodes[node].overwrite_specific_node_index_config[index].volumes[volume].size :
              (try(node_config.overwrite_defaults.volumes[volume].size, null) != null ?
                node_config.overwrite_defaults.volumes[volume].size : volume_config.size
              )
            )
            type = (
              try(
                var.config.nodes[node].overwrite_specific_node_index_config[index].volumes[volume].type, null
              ) != null ?
              var.config.nodes[node].overwrite_specific_node_index_config[index].volumes[volume].type :
              (try(node_config.overwrite_defaults.volumes[volume].type, null) != null ?
                node_config.overwrite_defaults.volumes[volume].type : volume_config.type
              )
            )
            iops = (
              try(
                var.config.nodes[node].overwrite_specific_node_index_config[index].volumes[volume].iops, null
              ) != null ?
              var.config.nodes[node].overwrite_specific_node_index_config[index].volumes[volume].iops :
              (try(node_config.overwrite_defaults.volumes[volume].iops, null) != null ?
                node_config.overwrite_defaults.volumes[volume].iops : volume_config.iops
              )
            )
            throughput = (
              try(
                var.config.nodes[node].overwrite_specific_node_index_config[index].volumes[volume].throughput,
                null
              ) != null ?
              var.config.nodes[node].overwrite_specific_node_index_config[index].volumes[volume].throughput :
              (try(node_config.overwrite_defaults.volumes[volume].throughput, null) != null ?
                node_config.overwrite_defaults.volumes[volume].throughput : volume_config.throughput
              )
            )
            device_name = (
              try(
                var.config.nodes[node].overwrite_specific_node_index_config[index].volumes[volume].device_name,
                null
              ) != null ?
              var.config.nodes[node].overwrite_specific_node_index_config[index].volumes[volume].device_name :
              (try(node_config.overwrite_defaults.volumes[volume].device_name, null) != null ?
                node_config.overwrite_defaults.volumes[volume].device_name :
                volume != "root" ? volume_config.device_name : null
              )
            )
            device_name_template = (
              try(
                var.config.nodes[node].overwrite_specific_node_index_config[index].volumes[volume].device_name_template,
                null
              ) != null ?
              var.config.nodes[node].overwrite_specific_node_index_config[index].volumes[volume].device_name_template :
              (try(node_config.overwrite_defaults.volumes[volume].device_name_template, null) != null ?
                node_config.overwrite_defaults.volumes[volume].device_name_template :
                volume != "root" ? volume_config.device_name_template : null
              )
            )
          } if contains(keys(local.default_nodes[node].volumes), volume)
        }
      }
    }
  ])...)
}

