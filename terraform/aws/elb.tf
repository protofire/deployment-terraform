resource "aws_lb" "lb" {
  for_each = { for node, node_config in local.inframap_elb :
    node => node_config if node_config.enabled
  }

  name               = replace(each.key, "_", "-")
  internal           = false
  load_balancer_type = "application"

  enable_deletion_protection = false

  security_groups = [aws_security_group.sgs[each.key].id]
  subnets         = [for subnet in aws_subnet.subnets : subnet.id]

  tags = {
    Name = title(each.key)
  }
}

resource "aws_lb_listener" "lb_listener" {
  for_each = { for node, node_config in local.inframap_elb :
    node => node_config if node_config.enabled
  }

  load_balancer_arn = aws_lb.lb[each.key].arn
  port              = each.value.port
  protocol          = each.value.port != 443 ? "HTTP" : "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg[each.key].arn
  }

  tags = {
    Name = title(each.key)
  }

  depends_on = [
    aws_lb.lb
  ]
}

resource "aws_lb_target_group" "lb_tg" {
  for_each = { for node, node_config in local.inframap_elb :
    node => node_config if node_config.enabled
  }

  name        = "bootnode-instances"
  port        = each.value.port
  target_type = "instance"
  protocol    = each.value.port != 443 ? "HTTP" : "HTTPS"
  vpc_id      = aws_vpc.this.id

  health_check {
    enabled             = true
    healthy_threshold   = 10
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 5
    port                = each.value.port
    protocol            = each.value.port != 443 ? "HTTP" : "HTTPS"
  }

  tags = {
    Name = title(each.key)
  }

  depends_on = [
    aws_lb.lb
  ]
}

resource "aws_lb_target_group_attachment" "lb_tg_attach" {
  for_each = { for node, node_config in local.inframap_nodes :
    node => merge(node_config,
      {
        lb_key = keys(local.inframap_elb)[0]
      }
      ) if(
      length(regexall("bootnode_", node)) > 0 == true &&
      try(node_config.elb.enabled, false)
    )
  }

  target_group_arn = aws_lb_target_group.lb_tg[each.value.lb_key].arn
  target_id        = aws_instance.nodes[each.key].id
  port             = local.inframap_elb[each.value.lb_key].port

  depends_on = [
    aws_lb.lb
  ]
}
