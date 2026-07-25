#!/bin/bash
# ================================================================================
# Active Directory + Dependent Server Deployment Orchestration Script
# ================================================================================
# Description:
#   Automates a two-phase AWS infrastructure build:
#     1. Active Directory (AD) Domain Controller.
#     2. Dependent EC2 servers that rely on the AD environment.
#
# Notes:
#   - Fail-fast enabled: any error terminates execution immediately.
# ================================================================================
 
set -euo pipefail
 
# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"
DNS_ZONE="mcloud.mikecloud.com"
 
# ------------------------------------------------------------------------------
# Environment Pre-Check
# ------------------------------------------------------------------------------
echo "NOTE: Running environment validation..."
./check_env.sh
 
# ------------------------------------------------------------------------------
# Phase 1: Build AD Instance
# ------------------------------------------------------------------------------
echo "NOTE: Building Active Directory instance..."
 
cd 01-directory || { echo "ERROR: Directory 01-directory not found"; exit 1; }
 
terraform init
terraform apply -auto-approve
 
cd ..
 
# ------------------------------------------------------------------------------
# Phase 2: Build EC2 Server Instances
# ------------------------------------------------------------------------------
echo "NOTE: Building EC2 server instances..."
 
cd 02-servers || { echo "ERROR: Directory 02-servers not found"; exit 1; }
 
terraform init
terraform apply -auto-approve
 
cd ..
 
# ------------------------------------------------------------------------------
# Build Validation
# ------------------------------------------------------------------------------
echo "NOTE: Running build validation..."
./validate.sh
 
echo "NOTE: Infrastructure build complete."
# ================================================================================
# End of Script
# ================================================================================
