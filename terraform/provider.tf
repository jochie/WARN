provider "aws" {
  shared_config_files = [ "~/.aws/config" ]
  profile = var.target_profile
  region = var.target_region
}
