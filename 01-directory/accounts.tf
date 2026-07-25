# ==============================================================================
# File: accounts.tf
# ------------------------------------------------------------------------------
# Purpose:
#   - Generates Active Directory (AD) user credentials for lab and quick-start
#     environments.
#   - Stores all credentials securely in AWS Secrets Manager.
#
# Scope:
#   - Creates a single AD Administrator account secret.
#   - Creates multiple standard AD user account secrets.
#   - Generates strong random passwords per account.
#
# Notes:
#   - Passwords are generated at apply time and never logged.
#   - Secrets are versioned automatically by AWS Secrets Manager.
#   - Usernames are constructed using the NetBIOS domain prefix.
#   - This file is intentionally explicit (non-dynamic) for clarity in
#     instructional and demo environments.
# ==============================================================================


# ==============================================================================
# AD ADMINISTRATOR ACCOUNT
# ==============================================================================

# ------------------------------------------------------------------------------
# Generate a random password for the AD Administrator account
# ------------------------------------------------------------------------------
resource "random_password" "admin_password" {
  length           = 24   # Total password length
  special          = true # Include special characters
  override_special = "_-" # Restrict special characters to safe set
}

# ------------------------------------------------------------------------------
# Secrets Manager secret for AD Administrator credentials
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "admin_secret" {
  name        = "admin_ad_credentials_efs"
  description = "AD Administrator Credentials (EFS)"

  lifecycle {
    prevent_destroy = false
  }
}

# ------------------------------------------------------------------------------
# Store AD Administrator credentials as a versioned secret
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret_version" "admin_secret_version" {
  secret_id = aws_secretsmanager_secret.admin_secret.id

  secret_string = jsonencode({
    username = "${var.netbios}\\Admin"
    password = random_password.admin_password.result
  })
}


# ==============================================================================
# STANDARD AD USER ACCOUNTS
# ==============================================================================

# ------------------------------------------------------------------------------
# User: John Smith (jsmith)
# ------------------------------------------------------------------------------

resource "random_password" "jsmith_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "aws_secretsmanager_secret" "jsmith_secret" {
  name        = "jsmith_ad_credentials_efs"
  description = "John Smith AD Credentials (EFS)"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_secretsmanager_secret_version" "jsmith_secret_version" {
  secret_id = aws_secretsmanager_secret.jsmith_secret.id

  secret_string = jsonencode({
    username = "${var.netbios}\\jsmith"
    password = random_password.jsmith_password.result
  })
}


# ------------------------------------------------------------------------------
# User: Emily Davis (edavis)
# ------------------------------------------------------------------------------

resource "random_password" "edavis_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "aws_secretsmanager_secret" "edavis_secret" {
  name        = "edavis_ad_credentials_efs"
  description = "Emily Davis AD Credentials (EFS)"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_secretsmanager_secret_version" "edavis_secret_version" {
  secret_id = aws_secretsmanager_secret.edavis_secret.id

  secret_string = jsonencode({
    username = "${var.netbios}\\edavis"
    password = random_password.edavis_password.result
  })
}


# ------------------------------------------------------------------------------
# User: Raj Patel (rpatel)
# ------------------------------------------------------------------------------

resource "random_password" "rpatel_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "aws_secretsmanager_secret" "rpatel_secret" {
  name        = "rpatel_ad_credentials_efs"
  description = "Raj Patel AD Credentials (EFS)"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_secretsmanager_secret_version" "rpatel_secret_version" {
  secret_id = aws_secretsmanager_secret.rpatel_secret.id

  secret_string = jsonencode({
    username = "${var.netbios}\\rpatel"
    password = random_password.rpatel_password.result
  })
}


# ------------------------------------------------------------------------------
# User: Amit Kumar (akumar)
# ------------------------------------------------------------------------------

resource "random_password" "akumar_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "aws_secretsmanager_secret" "akumar_secret" {
  name        = "akumar_ad_credentials_efs"
  description = "Amit Kumar AD Credentials (EFS)"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_secretsmanager_secret_version" "akumar_secret_version" {
  secret_id = aws_secretsmanager_secret.akumar_secret.id

  secret_string = jsonencode({
    username = "${var.netbios}\\akumar"
    password = random_password.akumar_password.result
  })
}
