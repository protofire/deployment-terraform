resource "aws_security_group" "sgs" {
  for_each = { for node, node_config in merge(local.inframap_security_groups,
    local.inframap_elb.bootnode_lb.enabled ? local.inframap_elb : {}) :
    node => node_config
  }

  name        = title(each.key)
  description = "Default ${title(each.key)} security group"

  vpc_id = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = title(each.key)
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "sg_rules" {
  for_each = merge(flatten([for node, node_config in merge(local.inframap_security_groups,
    local.inframap_elb.bootnode_lb.enabled ? local.inframap_elb : {}) :
    [for sg, sg_config in node_config.security_groups : {
      "${node}_${sg}" = {
        port     = sg_config.port
        protocol = sg_config.protocol
        cidr_blocks = (
          try(sg_config.source_security_group, null) == null &&
          can(aws_security_group.sgs[sg_config.source_security_group]) ?
          sg_config.cidr_blocks : null
        )
        description = sg
        source_security_group_id = (
          try(sg_config.source_security_group, null) != null &&
          can(aws_security_group.sgs[sg_config.source_security_group]) ?
          aws_security_group.sgs[sg_config.source_security_group].id :
          null
        )
        security_group_key = node
      } } if sg_config != null
    ]
  ])...)

  description = title(each.value.description)

  type                     = "ingress"
  from_port                = each.value.port
  to_port                  = each.value.port
  protocol                 = each.value.protocol
  cidr_blocks              = each.value.cidr_blocks
  source_security_group_id = each.value.source_security_group_id
  security_group_id        = aws_security_group.sgs[each.value.security_group_key].id
}
