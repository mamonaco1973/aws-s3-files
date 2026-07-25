# ================================================================================
# FILE: linux.tf
#
# Purpose:
#   - Resolves the latest Canonical Ubuntu 24.04 AMI.
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
#   - AMI resolution is dynamic and always tracks Canonical’s latest release.
#   - Instance is intended for lab/demo and S3 Files validation workflows.
# ================================================================================

# ================================================================================
# DATA: Canonical Ubuntu 24.04 AMI (SSM Parameter)
# ================================================================================
# Purpose:
#   - Fetches the current stable Ubuntu 24.04 LTS AMI ID.
#
# Notes:
#   - Parameter is maintained by Canonical.
#   - Architecture: amd64
#   - Virtualization: HVM
#   - Storage: gp3-backed EBS
# ================================================================================
data "aws_ssm_parameter" "ubuntu_24_04" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# ================================================================================
# DATA: Canonical Ubuntu 24.04 AMI Object
# ================================================================================
# Purpose:
#   - Resolves the full AMI object from the SSM-provided AMI ID.
#
# Notes:
#   - Owner is restricted to Canonical to prevent untrusted AMI usage.
#   - most_recent is retained as a safety guard.
# ================================================================================
data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ubuntu_24_04.value]
  }
}

# ================================================================================
# RESOURCE: aws_instance.s3files_client_instance
# ================================================================================
# Purpose:
#   - Provisions an Ubuntu 24.04 EC2 instance.
#   - Mounts the S3 Files file system and joins the Active Directory domain.
# ================================================================================
resource "aws_instance" "s3files_client_instance" {

  # ------------------------------------------------------------------------------
  # Amazon Machine Image
  # ------------------------------------------------------------------------------
  ami = data.aws_ami.ubuntu_ami.id

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
