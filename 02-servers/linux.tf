# ================================================================================
# FILE: linux.tf
#
# Purpose:
#   - Resolves the latest Amazon Linux 2023 AMI.
#   - Provisions an EC2 instance that mounts the S3 Files file system.
#   - Integrates the instance into the Active Directory domain.
#   - Re-exports the S3 Files mount over SMB so Windows clients can reach it.
#
# Scope:
#   - AMI discovery via SSM and EC2 metadata.
#   - Linux EC2 instance provisioning.
#   - S3 Files client configuration and AD integration.
#
# Notes:
#   - AL2023 ships amazon-efs-utils 3.x (mount.s3files) as a prebuilt dnf
#     package, avoiding an on-boot source build.
#   - Instance is intended for lab/demo and S3 Files validation workflows.
# ================================================================================

# ================================================================================
# DATA: Amazon Linux 2023 AMI (SSM Parameter)
# ================================================================================
# Purpose:
#   - Fetches the current Amazon Linux 2023 AMI ID.
#
# Notes:
#   - AL2023 is used for the gateway so amazon-efs-utils 3.x (which carries the
#     mount.s3files helper) installs prebuilt via `dnf` — no source build.
#   - Parameter is maintained by AWS. Architecture: x86_64, default kernel.
# ================================================================================
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ================================================================================
# DATA: Amazon Linux 2023 AMI Object
# ================================================================================
# Purpose:
#   - Resolves the full AMI object from the SSM-provided AMI ID.
#
# Notes:
#   - Owner is restricted to Amazon to prevent untrusted AMI usage.
# ================================================================================
data "aws_ami" "al2023_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.al2023.value]
  }
}

# ================================================================================
# RESOURCE: aws_instance.s3files_client_instance
# ================================================================================
# Purpose:
#   - Provisions an Amazon Linux 2023 EC2 instance.
#   - Mounts the S3 Files file system and joins the Active Directory domain.
# ================================================================================
resource "aws_instance" "s3files_client_instance" {

  # ------------------------------------------------------------------------------
  # Amazon Machine Image
  # ------------------------------------------------------------------------------
  ami = data.aws_ami.al2023_ami.id

  # ------------------------------------------------------------------------------
  # Instance Sizing
  # ------------------------------------------------------------------------------
  # Selected to balance cost and performance for S3 Files and AD testing.
  instance_type = "t3.medium"

  # ------------------------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------------------------
  subnet_id = data.aws_subnet.vm_subnet_1.id

  vpc_security_group_ids = [
    aws_security_group.ad_ssh_sg.id
  ]

  associate_public_ip_address = true

  # ------------------------------------------------------------------------------
  # IAM Instance Profile
  # ------------------------------------------------------------------------------
  # Grants access to required AWS services such as SSM and Secrets Manager.
  iam_instance_profile = aws_iam_instance_profile.ec2_secrets_profile.name

  # ------------------------------------------------------------------------------
  # User Data Bootstrap
  # ------------------------------------------------------------------------------
  # Performs initial configuration on first boot:
  #   - Mounts the S3 Files file system.
  #   - Joins the AD domain.
  #   - Applies group ownership and permissions.
  user_data = templatefile("./scripts/userdata.sh", {
    admin_secret  = "admin_ad_credentials_s3"
    domain_fqdn   = var.dns_zone
    s3files_fs_id = aws_s3files_file_system.s3fs.id
    netbios       = var.netbios
    realm         = var.realm
    force_group   = "mcloud-users"
  })

  # ------------------------------------------------------------------------------
  # Tags
  # ------------------------------------------------------------------------------
  tags = {
    Name = "s3-files-gateway"
  }

  # ------------------------------------------------------------------------------
  # Dependency Ordering
  # ------------------------------------------------------------------------------
  # Ensures the file system, its mount targets, and the client mount policy
  # exist before the instance tries to mount on first boot.
  depends_on = [
    aws_s3files_file_system.s3fs,
    aws_s3files_mount_target.s3fs_mnt_1,
    aws_s3files_mount_target.s3fs_mnt_2,
    aws_iam_role_policy.s3files_client
  ]
}
