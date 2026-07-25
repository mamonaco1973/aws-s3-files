# ================================================================================
# FILE: windows.tf
#
# Purpose:
#   - Provisions a Windows Server instance used as an AD administration
#     workstation.
#
# Scope:
#   - Windows EC2 instance provisioning for RDP-based management.
#   - Bootstrap configuration via PowerShell user data.
#
# Notes:
#   - This instance is NOT a domain controller.
#   - If a public IP is assigned, restrict RDP ingress to trusted CIDRs.
# ================================================================================

# ================================================================================
# RESOURCE: aws_instance.windows_ad_instance
# ================================================================================
# Purpose:
#   - Provides an administrative Windows host for managing the AD domain.
#   - Intended for RDP logins and running RSAT / AD management tooling.
# ================================================================================
resource "aws_instance" "windows_ad_instance" {

  # ------------------------------------------------------------------------------
  # Amazon Machine Image
  # ------------------------------------------------------------------------------
  # Resolved from a data source to track the most recent Windows Server AMI.
  ami = data.aws_ami.windows_ami.id

  # ------------------------------------------------------------------------------
  # Instance Sizing
  # ------------------------------------------------------------------------------
  # Sized for interactive administration sessions and common AD tooling.
  instance_type = "t3.medium"

  # ------------------------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------------------------
  subnet_id = data.aws_subnet.vm_subnet_1.id

  vpc_security_group_ids = [
    aws_security_group.ad_rdp_sg.id
  ]

  # Notes:
  #   - Assigning a public IP can expose RDP if security groups are open.
  #   - Prefer VPN, SSM Session Manager, or restricted admin CIDRs.
  associate_public_ip_address = true

  # ------------------------------------------------------------------------------
  # IAM Instance Profile
  # ------------------------------------------------------------------------------
  # Grants access to required AWS services such as SSM and Secrets Manager.
  iam_instance_profile = aws_iam_instance_profile.ec2_secrets_profile.name

  # ------------------------------------------------------------------------------
  # User Data Bootstrap
  # ------------------------------------------------------------------------------
  # Configures the instance to authenticate against the AD domain and
  # connects to supporting infrastructure for management workflows.
  user_data = templatefile("./scripts/userdata.ps1", {
    admin_secret = "admin_ad_credentials_efs"
    domain_fqdn  = var.dns_zone
    samba_server = aws_instance.efs_client_instance.private_dns
  })

  # ------------------------------------------------------------------------------
  # Tags
  # ------------------------------------------------------------------------------
  tags = {
    Name = "windows-ad-admin"
  }

  # ------------------------------------------------------------------------------
  # Dependency Ordering
  # ------------------------------------------------------------------------------
  # Ensures supporting Linux/Samba host exists before this admin host boots.
  depends_on = [aws_instance.efs_client_instance]
}
