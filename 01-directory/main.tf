# ================================================================================
# Terraform Provider Requirements
# ================================================================================
# Purpose:
#   - Declares all providers required by this stack.
#
# Notes:
#   - AWS provider manages infrastructure resources.
#   - Time provider is used for deterministic post-create delays
#     (e.g., NAT Gateway stabilization).
# ================================================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# ================================================================================
# AWS Provider Configuration
# ================================================================================
# Purpose:
#   - Configures the AWS provider for all resources in this stack.
#
# Notes:
#   - Set the deployment region explicitly to avoid accidental cross-region builds.
# ================================================================================
provider "aws" {
  region = "us-east-1"
}
