# ================================================================================
# SECURITY GROUPS: Lab Access Rules (RDP / SSH / SMB / ICMP)
# ================================================================================
# Purpose:
#   - Provides connectivity to lab instances for administration and testing.
#   - RDP is used for Windows instance access.
#   - SSH is used for Linux instance access.
#   - SMB/445 is included for AD/Samba testing scenarios.
#   - ICMP is enabled for basic reachability checks.
#
# Notes:
#   - Ingress is currently open to 0.0.0.0/0 for demo purposes.
#   - Production deployments must restrict ingress to trusted CIDRs or
#     security-group sources.
# ================================================================================

# ================================================================================
# RESOURCE: aws_security_group.ad_rdp_sg
# ================================================================================
# Purpose:
#   - Allows Remote Desktop (TCP/3389) access to Windows instances.
# ================================================================================
resource "aws_security_group" "ad_rdp_sg" {
  name        = "efs-rdp-security-group"
  description = "Allow RDP access from the internet"
  vpc_id      = data.aws_vpc.ad_vpc.id

  # ------------------------------------------------------------------------------
  # INGRESS: RDP (TCP/3389)
  # ------------------------------------------------------------------------------
  ingress {
    description = "Allow RDP from anywhere (demo only)"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ------------------------------------------------------------------------------
  # INGRESS: ICMP (Ping)
  # ------------------------------------------------------------------------------
  ingress {
    description = "Allow ICMP from anywhere (demo only)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ------------------------------------------------------------------------------
  # EGRESS: ALL
  # ------------------------------------------------------------------------------
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ================================================================================
# RESOURCE: aws_security_group.ad_ssh_sg
# ================================================================================
# Purpose:
#   - Allows SSH (TCP/22) access to Linux instances.
#   - Allows SMB (TCP/445) for AD/Samba testing scenarios.
# ================================================================================
resource "aws_security_group" "ad_ssh_sg" {
  name        = "efs-ssh-security-group"
  description = "Allow SSH access from the internet"
  vpc_id      = data.aws_vpc.ad_vpc.id

  # ------------------------------------------------------------------------------
  # INGRESS: SSH (TCP/22)
  # ------------------------------------------------------------------------------
  ingress {
    description = "Allow SSH from anywhere (demo only)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ------------------------------------------------------------------------------
  # INGRESS: SMB (TCP/445)
  # ------------------------------------------------------------------------------
  ingress {
    description = "Allow SMB from anywhere (demo only)"
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ------------------------------------------------------------------------------
  # INGRESS: ICMP (Ping)
  # ------------------------------------------------------------------------------
  ingress {
    description = "Allow ICMP from anywhere (demo only)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ------------------------------------------------------------------------------
  # EGRESS: ALL
  # ------------------------------------------------------------------------------
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
