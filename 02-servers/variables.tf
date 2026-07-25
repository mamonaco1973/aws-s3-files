# ================================================================================
# Active Directory Naming Inputs
# ================================================================================
# Purpose:
#   - Defines AD domain identity inputs used by Samba and Kerberos.
#
# Notes:
#   - dns_zone is the AD DNS domain (FQDN).
#   - realm is typically dns_zone in uppercase for Kerberos.
#   - netbios is the short legacy domain name (<= 15 chars recommended).
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
#   - Convention is to match dns_zone in uppercase.
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

# ================================================================================
# Networking Inputs
# ================================================================================

# ------------------------------------------------------------------------------
# VARIABLE: vpc_name
# ------------------------------------------------------------------------------
# Purpose:
#   - Name tag used to locate or label the target VPC.
# ------------------------------------------------------------------------------
variable "vpc_name" {
  description = "Name for the VPC"
  type        = string
  default     = "efs-vpc"
}
