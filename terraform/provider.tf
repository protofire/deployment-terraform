terraform {

  # backend "s3" {}

  required_version = ">=1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.59.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  alias   = "use1"
  profile = "protofire-personal"
  default_tags {
    tags = {
      Owner = "Protofire"
    }
  }
}

provider "aws" {
  region  = "us-east-2"
  alias   = "use2"
  profile = "protofire-personal"
  default_tags {
    tags = {
      Owner = "Protofire"
    }
  }
}

provider "aws" {
  region  = "us-west-1"
  alias   = "usw1"
  profile = "protofire-personal"
  default_tags {
    tags = {
      Owner = "Protofire"
    }
  }
}
