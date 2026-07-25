# ================================================================================
# FILE: variables.tf
#
# Purpose:
#   - Defines input variables for the mini-ad deployment.
#   - Controls domain naming, Kerberos configuration, and LDAP placement.
#
# Scope:
#   - Active Directory DNS naming.
#   - Kerberos realm configuration.
#   - NetBIOS and LDAP user base definitions.
#
# Notes:
#   - Defaults are suitable for lab and demo environments only.
#   - Production deployments should override all defaults explicitly.
# ================================================================================

# ================================================================================
# Active Directory Naming Inputs
# ================================================================================

# ------------------------------------------------------------------------------
# VARIABLE: dns_zone
# ------------------------------------------------------------------------------
# Purpose:
#   - Fully qualified DNS name for the AD domain.
# ------------------------------------------------------------------------------
variable "dns_zone" {
  description = "AD DNS zone / domain (e.g., mcloud.mikecloud.com)"
  type        = string
  default     = "mcloud.mikecloud.com"
}

# ------------------------------------------------------------------------------
# VARIABLE: realm
# ------------------------------------------------------------------------------
# Purpose:
#   - Kerberos realm for the AD domain.
#
# Notes:
#   - Typically matches dns_zone in uppercase.
# ------------------------------------------------------------------------------
variable "realm" {
  description = "Kerberos realm (uppercase DNS domain)"
  type        = string
  default     = "MCLOUD.MIKECLOUD.COM"
}

# ------------------------------------------------------------------------------
# VARIABLE: netbios
# ------------------------------------------------------------------------------
# Purpose:
#   - Short NetBIOS domain name for legacy and SMB clients.
#
# Notes:
#   - Recommended length is 15 characters or fewer.
# ------------------------------------------------------------------------------
variable "netbios" {
  description = "NetBIOS short domain name (e.g., MCLOUD)"
  type        = string
  default     = "MCLOUD"
}

# ------------------------------------------------------------------------------
# VARIABLE: user_base_dn
# ------------------------------------------------------------------------------
# Purpose:
#   - Base distinguished name for user objects in LDAP.
# ------------------------------------------------------------------------------
variable "user_base_dn" {
  description = "LDAP base DN for user accounts"
  type        = string
  default     = "CN=Users,DC=mcloud,DC=mikecloud,DC=com"
}

# ================================================================================
# Networking Inputs
# ================================================================================

# ------------------------------------------------------------------------------
# VARIABLE: vpc_name
# ------------------------------------------------------------------------------
# Purpose:
#   - Logical name applied to the VPC resource.
# ------------------------------------------------------------------------------
variable "vpc_name" {
  description = "Name for the VPC"
  type        = string
  default     = "efs-vpc"
}
