# ================================================================================
# FILE: efs.tf
#
# Purpose:
#   - Provisions an Amazon EFS file system for shared NFS storage.
#   - Exposes EFS to EC2 instances via mount targets and a dedicated
#     security group.
#
# Scope:
#   - EFS security group
#   - EFS file system
#   - EFS mount targets
#
# Notes:
#   - Current NFS ingress rules are open for lab/demo use only.
#   - Production deployments must restrict NFS access explicitly.
# ================================================================================

# ================================================================================
# RESOURCE: aws_security_group.efs_sg
# ================================================================================
# Purpose:
#   - Allows NFS (TCP/2049) access to the EFS file system.
#
# Notes:
#   - Ingress is currently open to 0.0.0.0/0 for demo purposes.
#   - Restrict to trusted CIDRs or security groups in production.
# ================================================================================
resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Security group allowing NFS traffic to EFS"
  vpc_id      = data.aws_vpc.ad_vpc.id

  # ------------------------------------------------------------------------------
  # INGRESS: NFS (TCP/2049)
  # ------------------------------------------------------------------------------
  ingress {
    description = "Allow inbound NFS traffic"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ------------------------------------------------------------------------------
  # EGRESS: ALL
  # ------------------------------------------------------------------------------
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs-sg"
  }
}

# ================================================================================
# RESOURCE: aws_efs_file_system.efs
# ================================================================================
# Purpose:
#   - Creates a managed, encrypted EFS file system.
#
# Notes:
#   - Access is limited to VPC mount targets.
#   - Encryption at rest is enabled by default.
# ================================================================================
resource "aws_efs_file_system" "efs" {
  creation_token = "mcloud-efs"
  encrypted      = true

  tags = {
    Name = "mcloud-efs"
  }
}

# ================================================================================
# RESOURCES: aws_efs_mount_target
# ================================================================================
# Purpose:
#   - Attaches the EFS file system to specific subnets.
#
# Notes:
#   - One mount target is required per Availability Zone.
#   - Each AZ supports a single mount target per EFS file system.
# ================================================================================

# ------------------------------------------------------------------------------
# RESOURCE: aws_efs_mount_target.efs_mnt_1
# ------------------------------------------------------------------------------
resource "aws_efs_mount_target" "efs_mnt_1" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = data.aws_subnet.vm_subnet_1.id
  security_groups = [aws_security_group.efs_sg.id]
}

# ------------------------------------------------------------------------------
# RESOURCE: aws_efs_mount_target.efs_mnt_2
# ------------------------------------------------------------------------------
resource "aws_efs_mount_target" "efs_mnt_2" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = data.aws_subnet.ad_subnet.id
  security_groups = [aws_security_group.efs_sg.id]
}
