#!/bin/bash
# ==============================================================================
# validate.sh - EFS + Active Directory Quick Start Validation
# ------------------------------------------------------------------------------
# Purpose:
#   - Queries AWS for expected EC2 instances and prints quick-start endpoints.
#
# Scope:
#   - Looks up instances by Name tag:
#       - windows-ad-admin
#       - efs-client-gateway
#   - Prints public DNS names for fast copy/paste access.
#
# Fast-Fail Behavior:
#   - Script exits immediately on command failure, unset variables,
#     or failed pipelines.
#
# Requirements:
#   - AWS CLI installed and authenticated.
#   - Instances must be tagged with the expected Name values.
# ==============================================================================
 
set -euo pipefail
 
# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"
 
# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
get_public_dns_by_name_tag() {
  local name_tag="$1"
 
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${name_tag}" \
    --query "Reservations[].Instances[].PublicDnsName" \
    --output text | xargs
}
 
# ------------------------------------------------------------------------------
# Lookups
# ------------------------------------------------------------------------------
windows_dns="$(get_public_dns_by_name_tag "windows-ad-admin")"
linux_dns="$(get_public_dns_by_name_tag "efs-client-gateway")"
 
# ------------------------------------------------------------------------------
# Quick Start Output
# ------------------------------------------------------------------------------
echo ""
echo "============================================================================"
echo "EFS + Active Directory Quick Start - Validation Output"
echo "============================================================================"
echo ""
 
if [ -n "${windows_dns}" ] && [ "${windows_dns}" != "None" ]; then
  echo "NOTE: Windows RDP Host FQDN: ${windows_dns}"
else
  echo "WARN: windows-ad-admin not found or has no public DNS"
fi
 
if [ -n "${linux_dns}" ] && [ "${linux_dns}" != "None" ]; then
  echo "NOTE: Linux SSH Host FQDN:  ${linux_dns}"
else
  echo "WARN: efs-client-gateway not found or has no public DNS"
fi
 
echo ""
echo "NOTE: Validation complete."
echo ""
