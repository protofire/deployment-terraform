locals {
  public_key_path = "~/.ssh/protofire-ansible.pub"
  inframap = {
    aws = {
      use1 = {
        nodes = {
          netstat = {
            count = 1
          }
          bootnode = {
            count = 2
          }
          bridge = {
            count = 2
          }
          validator = {
            count = 3
          }
          owner = {
            count = 1
          }
        }

        keypair_public_key = local.public_key_path
      }
      use2 = {
        nodes = {
          netstat = {
            count = 0
          }
          bootnode = {
            count = 1
            overwrite_defaults = {
              security_groups = {
                http = null
                rpc = {
                  port = 8545
                }
              }
            }
            overwrite_specific_node_index_config = {
              1 = {
                instance_name = "Bootnode Archive"
                elb = {
                  enabled = false
                }
                volumes = {
                  data = {
                    size = 100
                  }
                }
              }
            }
          }
        }
        bridge = {
          count = 2
          overwrite_defaults = {
            instance_name = "Bridge Validator 2"
          }
        }
        validator = {
          count         = 1
          instance_name = "Validator 2"
        }
        owner = {
          count = 0
        }

        keypair_public_key = local.public_key_path
      }
      usw1 = {
        nodes = {
          netstat = {
            count = 0
          }
          bootnode = {
            count = 0
          }
          bridge = {
            count         = 2
            instance_name = "Bridge Validator 3"
          }
          validator = {
            count         = 1
            instance_name = "Validator 3"
          }
          owner = {
            count = 0
          }
        }

        keypair_public_key = local.public_key_path
      }
    }
  }
}
