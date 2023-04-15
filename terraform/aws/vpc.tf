resource "aws_vpc" "this" {
  cidr_block = var.config.vpc_cidr_block

  enable_dns_hostnames = true

  tags = {
    Name = title(var.config.infrastructure_name)
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = title(var.config.infrastructure_name)
  }
}

resource "aws_default_route_table" "this" {
  default_route_table_id = aws_vpc.this.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = title(var.config.infrastructure_name)
  }
}

data "aws_region" "this" {}

data "aws_availability_zones" "this" {
  state = "available"
}

resource "aws_subnet" "subnets" {
  for_each = toset([for item in var.config.availability_zones :
    item if contains(
      data.aws_availability_zones.this.names,
      "${data.aws_region.this.name}${item}"
    )
  ])

  vpc_id            = aws_vpc.this.id
  availability_zone = "${data.aws_region.this.name}${each.value}"
  cidr_block = cidrsubnet(
    var.config.vpc_cidr_block,
    8,
    index(var.config.availability_zones, each.value)
  )

  tags = {
    Name = title(var.config.infrastructure_name)
  }
}
