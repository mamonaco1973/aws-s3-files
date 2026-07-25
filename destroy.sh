#!/bin/bash
# ================================================================================
# File: destroy.sh
#
# Purpose:
#   - Performs a controlled teardown of the mini-ad environment.
#   - Destroys dependent server resources first.
#   - Deletes AD-related secrets and then destroys the AD stack.
#
# Scope:
#   - Terraform-managed EC2 server instances.
#   - AWS Secrets Manager secrets for AD users and administrators.
#   - Terraform-managed Active Directory infrastructure.
#
# Notes:
#   - Secrets are deleted permanently with no recovery window.
#   - This action is destructive and cannot be undone.
#   - Intended for lab and demo environments only.
# ================================================================================
 
# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"
 
# ------------------------------------------------------------------------------
# Phase 1: Destroy Server EC2 Instances
# ------------------------------------------------------------------------------
# Notes:
#   - Dependent servers must be destroyed before AD to avoid teardown
#     failures and dependency issues.
# ------------------------------------------------------------------------------
echo "NOTE: Destroying EC2 server instances and S3 Files storage..."

cd 02-servers || { echo "ERROR: Directory 02-servers not found"; exit 1; }

# Reinitialize Terraform to ensure providers and backend are available.
terraform init

# First pass: tears down instances and mount targets. This can fail on the
# S3 Files file system, which returns a terminal ConflictException while it
# still has data pending export to S3 (the provider has no force_delete arg).
# Tolerate that failure so we can force-delete below.
terraform destroy -auto-approve || true

# If the file system survived, force-delete it via the API (bypasses the
# pending-export wait — safe because the backing bucket is torn down too),
# drop it from state, then let the second pass finish the job.
fs_id=$(terraform show -json 2>/dev/null \
  | jq -r '.values.root_module.resources[]?
           | select(.type=="aws_s3files_file_system") | .values.id' \
  | head -n1)

if [ -n "$fs_id" ] && [ "$fs_id" != "null" ]; then
  echo "NOTE: Force-deleting S3 Files file system $fs_id..."
  aws s3files delete-file-system --file-system-id "$fs_id" --force-delete || true
  sleep 60  # let the file system finish deleting before the retry
  terraform state rm aws_s3files_file_system.s3fs || true
fi

# Second pass: removes the bucket (force_destroy) and anything left over.
# No-op if the first pass already succeeded.
terraform destroy -auto-approve

cd .. || exit
 
# ------------------------------------------------------------------------------
# Phase 2: Delete AD Secrets and Destroy AD Infrastructure
# ------------------------------------------------------------------------------
# Notes:
#   - Secrets are removed before AD teardown to avoid orphaned credentials.
#   - Deletion uses force-delete with no recovery window.
# ------------------------------------------------------------------------------
echo "NOTE: Deleting AD-related AWS secrets and parameters..."
 
# Permanently delete AD user and admin secrets from Secrets Manager.
aws secretsmanager delete-secret \
  --secret-id "akumar_ad_credentials_s3" \
  --force-delete-without-recovery
 
aws secretsmanager delete-secret \
  --secret-id "jsmith_ad_credentials_s3" \
  --force-delete-without-recovery
 
aws secretsmanager delete-secret \
  --secret-id "edavis_ad_credentials_s3" \
  --force-delete-without-recovery
 
aws secretsmanager delete-secret \
  --secret-id "rpatel_ad_credentials_s3" \
  --force-delete-without-recovery
 
aws secretsmanager delete-secret \
  --secret-id "admin_ad_credentials_s3" \
  --force-delete-without-recovery
 
# ------------------------------------------------------------------------------
# Phase 3: Destroy Active Directory Infrastructure
# ------------------------------------------------------------------------------
echo "NOTE: Destroying AD instance..."
 
cd 01-directory || { echo "ERROR: Directory 01-directory not found"; exit 1; }
 
terraform init
terraform destroy -auto-approve
 
cd .. || exit
 
# ------------------------------------------------------------------------------
# Completion
# ------------------------------------------------------------------------------
echo "NOTE: Infrastructure destruction complete."
# ================================================================================
# End of Script
# ================================================================================
