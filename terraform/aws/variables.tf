variable "config" {
  type = object({
    vpc_cidr_block     = optional(string, "10.0.0.0/16")
    availability_zones = optional(list(string), ["a", "b", "c"])
    image_id           = optional(string, "ubuntu")
    custom_image_id_source = optional(object({
      filter_image_names = list(string)
      owners             = list(string)
    }))

    infrastructure_name = optional(string, "Pchain")

    keypair_name       = optional(string, "pchain")
    keypair_public_key = optional(string)
    ec2_username       = optional(string, "protoadmin")

    nodes = optional(map(object({
      count = number
      overwrite_defaults = optional(object({
        instance_name = optional(string)
        instance_type = optional(string)
        image_id      = optional(string)
        elb = optional(object({
          enabled     = optional(bool, true)
          port        = optional(number, 80)
          protocol    = optional(string, "tpc")
          cidr_blocks = optional(list(string), ["0.0.0.0/0"])
        }))
        volumes = optional(map(object({
          size                 = optional(number)
          type                 = optional(string)
          iops                 = optional(number)
          throughput           = optional(number)
          device_name          = optional(string)
          device_name_template = optional(string)
        })), {})
        security_groups = optional(map(object({
          port        = number
          protocol    = optional(string, "tcp")
          cidr_blocks = optional(list(string), ["0.0.0.0/0"])
        })), {})
      }), {})
      overwrite_specific_node_index_config = optional(map(object({
        instance_name = optional(string)
        instance_type = optional(string)
        image_id      = optional(string)
        elb = optional(object({
          enabled = optional(bool, true)
        }), {})
        availability_zone = optional(string)
        volumes = optional(map(object({
          size                 = optional(number)
          type                 = optional(string)
          iops                 = optional(number)
          throughput           = optional(number)
          device_name          = optional(string)
          device_name_template = optional(string)
        })), {})
      })), {})
    })), {})
  })
  description = "POA Network infrastructure configuration"
}

variable "ansible_inventory" {
  type = object({
    generate    = optional(bool, true)
    output_file = optional(string, null)
  })
  description = "Ansible inventory file params"
  default = {
    generate    = true
    output_file = null
  }
}
