# ================================================================================
# FILE: main.tf
#
# Purpose:
#   - Configures the AWS provider for this stack.
#   - Discovers required existing infrastructure by tags.
#   - Locates Secrets Manager credentials and base AMIs.
#
# Scope:
#   - AWS provider configuration.
#   - Secrets Manager secret discovery for AD admin credentials.
#   - VPC and subnet discovery via Name tags.
#   - Windows Server 2022 AMI discovery.
#
# Notes:
#   - Tag-based discovery assumes the network baseline exists already.
#   - Ensure Name tags are unique within the target account/region.
# ================================================================================

# ================================================================================
# AWS Provider Configuration
# ================================================================================
provider "aws" {
  region = "us-east-1"
}

# ================================================================================
# DATA: Secrets Manager - AD Admin Credentials
# ================================================================================
# Purpose:
#   - Locates the secret storing AD admin credentials for authentication.
# ================================================================================
data "aws_secretsmanager_secret" "admin_secret" {
  name = "admin_ad_credentials_efs"
}

# ================================================================================
# DATA: VPC Discovery
# ================================================================================
# Purpose:
#   - Locates the target VPC by Name tag.
# ================================================================================
data "aws_vpc" "ad_vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

# ================================================================================
# DATA: Subnet Discovery
# ================================================================================
# Purpose:
#   - Locates required subnets by Name tag within the target VPC.
#
# Notes:
#   - VPC scoping is enforced using the vpc-id filter.
# ================================================================================

# ------------------------------------------------------------------------------
# DATA: aws_subnet.vm_subnet_1
# ------------------------------------------------------------------------------
data "aws_subnet" "vm_subnet_1" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.ad_vpc.id]
  }

  filter {
    name   = "tag:Name"
    values = ["vm-subnet-1"]
  }
}

# ------------------------------------------------------------------------------
# DATA: aws_subnet.ad_subnet
# ------------------------------------------------------------------------------
data "aws_subnet" "ad_subnet" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.ad_vpc.id]
  }

  filter {
    name   = "tag:Name"
    values = ["ad-subnet"]
  }
}

# ================================================================================
# DATA: Windows Server 2022 AMI Discovery
# ================================================================================
# Purpose:
#   - Locates the most recent AWS-provided Windows Server 2022 AMI.
#
# Notes:
#   - Owner is restricted to Amazon to avoid untrusted AMI sources.
# ================================================================================
data "aws_ami" "windows_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}
