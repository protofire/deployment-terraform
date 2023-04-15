module "poanetwork_use1" {
  source = "./aws"

  config = local.inframap.aws.use1

  providers = {
    aws = aws.use1
  }
}

module "poanetwork_use2" {
  source = "./aws"

  config = local.inframap.aws.use2

  providers = {
    aws = aws.use2
  }
}

module "poanetwork_usw1" {
  source = "./aws"

  config = local.inframap.aws.usw1

  providers = {
    aws = aws.usw1
  }
}
