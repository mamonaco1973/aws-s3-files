# ================================================================================
# FILE: ad.tf
#
# Purpose:
#   - Invokes the reusable mini-ad Terraform module
#   - Provisions an Ubuntu-based Active Directory Domain Controller
#
# Scope:
#   - AD domain creation
#   - DNS integration
#   - Initial user provisioning via JSON template
#
# Notes:
#   - Module assumes outbound internet access for package installation
#   - User passwords are generated dynamically and injected at bootstrap
# ================================================================================

# ================================================================================
# MODULE: Mini Active Directory (mini-ad)
# ================================================================================

module "mini_ad" {
  source = "github.com/mamonaco1973/module-aws-mini-ad"

  # ------------------------------------------------------------------------------
  # Domain Identity
  # ------------------------------------------------------------------------------
  netbios = var.netbios
  realm   = var.realm

  # ------------------------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------------------------
  vpc_id    = aws_vpc.ad-vpc.id
  subnet_id = aws_subnet.ad-subnet.id
  dns_zone  = var.dns_zone

  # ------------------------------------------------------------------------------
  # Authentication and User Provisioning
  # ------------------------------------------------------------------------------
  ad_admin_password = random_password.admin_password.result
  user_base_dn      = var.user_base_dn
  users_json        = local.users_json

  # ------------------------------------------------------------------------------
  # Dependency Ordering
  # ------------------------------------------------------------------------------
  # Ensures outbound connectivity is available before instance bootstrap.
  # Required for package repositories and initial configuration steps.
  # ------------------------------------------------------------------------------
  depends_on = [
    aws_nat_gateway.ad_nat,
    aws_route_table_association.rt_assoc_ad_private
  ]
}

# ================================================================================
# LOCALS: users_json
# ================================================================================

# ------------------------------------------------------------------------------
# Purpose:
#   - Renders users.json from a template file
#   - Injects dynamically generated passwords for demo users
#
# Notes:
#   - Output is passed directly into instance bootstrap logic
#   - Users are created automatically during first boot
# ------------------------------------------------------------------------------

locals {
  users_json = templatefile("./scripts/users.json.template", {
    USER_BASE_DN = var.user_base_dn
    DNS_ZONE     = var.dns_zone
    REALM        = var.realm
    NETBIOS      = var.netbios

    jsmith_password = random_password.jsmith_password.result
    edavis_password = random_password.edavis_password.result
    rpatel_password = random_password.rpatel_password.result
    akumar_password = random_password.akumar_password.result
  })
}
