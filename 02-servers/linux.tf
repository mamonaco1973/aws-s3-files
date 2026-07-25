# ================================================================================
# FILE: linux.tf
#
# Purpose:
#   - Resolves the latest Canonical Ubuntu 24.04 AMI.
#   - Provisions an EC2 instance that mounts Amazon EFS.
#   - Integrates the instance into the Active Directory domain.
#
# Scope:
#   - AMI discovery via SSM and EC2 metadata.
#   - Linux EC2 instance provisioning.
#   - EFS client configuration and AD integration.
#
# Notes:
#   - AMI resolution is dynamic and always tracks Canonical’s latest release.
#   - Instance is intended for lab/demo and EFS validation workflows.
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
# RESOURCE: aws_instance.efs_client_instance
# ================================================================================
# Purpose:
#   - Provisions an Ubuntu 24.04 EC2 instance.
#   - Mounts Amazon EFS and joins the Active Directory domain.
# ================================================================================
resource "aws_instance" "efs_client_instance" {

  # ------------------------------------------------------------------------------
  # Amazon Machine Image
  # ------------------------------------------------------------------------------
  ami = data.aws_ami.ubuntu_ami.id

  # ------------------------------------------------------------------------------
  # Instance Sizing
  # ------------------------------------------------------------------------------
  # Selected to balance cost and performance for EFS and AD testing.
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
  #   - Mounts the EFS file system.
  #   - Joins the AD domain.
  #   - Applies group ownership and permissions.
  user_data = templatefile("./scripts/userdata.sh", {
    admin_secret   = "admin_ad_credentials_efs"
    domain_fqdn    = var.dns_zone
    efs_mnt_server = aws_efs_mount_target.efs_mnt_1.dns_name
    netbios        = var.netbios
    realm          = var.realm
    force_group    = "mcloud-users"
  })

  # ------------------------------------------------------------------------------
  # Tags
  # ------------------------------------------------------------------------------
  tags = {
    Name = "efs-client-gateway"
  }

  # ------------------------------------------------------------------------------
  # Dependency Ordering
  # ------------------------------------------------------------------------------
  # Ensures EFS and mount targets are available before instance bootstrap.
  depends_on = [
    aws_efs_file_system.efs,
    aws_efs_mount_target.efs_mnt_1,
    aws_efs_mount_target.efs_mnt_2
  ]
}
