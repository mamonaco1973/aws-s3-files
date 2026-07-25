# ================================================================================
# FILE: s3-files.tf
#
# Purpose:
#   - Provisions an Amazon S3 Files file system: a managed NFS v4.2 front end
#     over a standard S3 bucket. The bucket stays the source of truth; S3 Files
#     (built on EFS under the hood) serves the active working set with low
#     latency and syncs writes back to S3.
#   - Exposes the file system to EC2 via mount targets and an NFS (TCP/2049)
#     security group, mirroring how the original EFS lab was wired.
#
# Scope:
#   - S3 bucket + versioning (S3 Files requires versioning enabled).
#   - IAM service role assumed by the S3 Files service (S3 + EventBridge).
#   - S3 Files file system and per-AZ mount targets.
#   - NFS security group for the mount targets.
#
# Notes:
#   - S3 Files is Linux/NFS only; Windows reaches it through the Samba gateway.
#   - NFS ingress is open for lab/demo use only — restrict in production.
#   - Requires AWS provider >= 6.40 (see main.tf) for the aws_s3files_* set.
# ================================================================================

# ================================================================================
# RANDOM SUFFIX: Globally-Unique Bucket Name
# ================================================================================
# Purpose:
#   - S3 bucket names are global; suffix avoids collisions across deployments.
# ================================================================================
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ================================================================================
# RESOURCE: aws_s3_bucket.s3files
# ================================================================================
# Purpose:
#   - Backing object store for the S3 Files file system.
# ================================================================================
resource "aws_s3_bucket" "s3files" {
  bucket = "mcloud-s3files-${random_id.bucket_suffix.hex}"

  # The gateway seeds the share with objects, and versioning keeps old
  # versions — force_destroy lets `terraform destroy` empty the bucket
  # (all objects and versions) instead of failing with BucketNotEmpty.
  force_destroy = true

  tags = {
    Name = "mcloud-s3files"
  }
}

# ================================================================================
# RESOURCE: aws_s3_bucket_versioning.s3files
# ================================================================================
# Purpose:
#   - S3 Files requires versioning; it relies on it to reconcile file-system
#     writes against concurrent S3 API changes.
# ================================================================================
resource "aws_s3_bucket_versioning" "s3files" {
  bucket = aws_s3_bucket.s3files.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ================================================================================
# RESOURCE: aws_s3_bucket_public_access_block.s3files
# ================================================================================
# Purpose:
#   - Defense-in-depth: the file system is reached over NFS in-VPC, never via
#     public object access.
# ================================================================================
resource "aws_s3_bucket_public_access_block" "s3files" {
  bucket = aws_s3_bucket.s3files.id

  block_public_acls       = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true
}

# ================================================================================
# RESOURCE: aws_iam_role.s3files_service
# ================================================================================
# Purpose:
#   - Role the S3 Files service assumes to read/write the bucket and manage the
#     EventBridge rule it uses to track object changes.
#
# Notes:
#   - S3 Files is built on EFS, so the trusted principal is the EFS service.
# ================================================================================
resource "aws_iam_role" "s3files_service" {
  name = "s3files-service-${local.iam_id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "elasticfilesystem.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ================================================================================
# RESOURCE: aws_iam_role_policy.s3files_service
# ================================================================================
# Purpose:
#   - Grants the service role object access on the backing bucket plus the
#     EventBridge permissions S3 Files needs to observe bucket changes.
# ================================================================================
resource "aws_iam_role_policy" "s3files_service" {
  name = "s3files-service-access"
  role = aws_iam_role.s3files_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.s3files.arn,
          "${aws_s3_bucket.s3files.arn}/*"
        ]
      },
      {
        # S3 Files manages an EventBridge rule to pick up out-of-band S3
        # writes; rule names are service-generated, so scope is account-wide.
        Sid    = "EventBridgeAccess"
        Effect = "Allow"
        Action = [
          "events:PutRule",
          "events:PutTargets",
          "events:DeleteRule",
          "events:RemoveTargets",
          "events:DescribeRule",
          "events:ListTargetsByRule"
        ]
        Resource = "*"
      }
    ]
  })
}

# ================================================================================
# RESOURCE: aws_security_group.s3files_sg
# ================================================================================
# Purpose:
#   - Allows NFS (TCP/2049) from the VPC to the S3 Files mount targets.
#
# Notes:
#   - Ingress is open to 0.0.0.0/0 for demo purposes only.
# ================================================================================
resource "aws_security_group" "s3files_sg" {
  name        = "s3files-sg"
  description = "Security group allowing NFS traffic to S3 Files mount targets"
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
    Name = "s3files-sg"
  }
}

# ================================================================================
# RESOURCE: aws_s3files_file_system.s3fs
# ================================================================================
# Purpose:
#   - Creates the S3 Files file system over the backing bucket. Mounting uses
#     the returned file-system id (fs-...), like an EFS mount helper target.
#
# Notes:
#   - accept_bucket_warning acknowledges S3 Files' configuration advisories
#     (e.g. an existing lifecycle/replication setup) so apply is non-interactive.
#   - Depends on versioning being active before the file system is created.
# ================================================================================
resource "aws_s3files_file_system" "s3fs" {
  bucket                = aws_s3_bucket.s3files.arn
  role_arn              = aws_iam_role.s3files_service.arn
  accept_bucket_warning = true

  tags = {
    Name = "mcloud-s3files"
  }

  depends_on = [
    aws_s3_bucket_versioning.s3files,
    aws_iam_role_policy.s3files_service
  ]
}

# ================================================================================
# RESOURCES: aws_s3files_mount_target
# ================================================================================
# Purpose:
#   - Places an NFS endpoint (ENI) for the file system in each subnet so
#     in-VPC clients can mount it. One mount target per AZ.
# ================================================================================

# ------------------------------------------------------------------------------
# RESOURCE: aws_s3files_mount_target.s3fs_mnt_1
# ------------------------------------------------------------------------------
resource "aws_s3files_mount_target" "s3fs_mnt_1" {
  file_system_id  = aws_s3files_file_system.s3fs.id
  subnet_id       = data.aws_subnet.vm_subnet_1.id
  security_groups = [aws_security_group.s3files_sg.id]
}

# ------------------------------------------------------------------------------
# RESOURCE: aws_s3files_mount_target.s3fs_mnt_2
# ------------------------------------------------------------------------------
resource "aws_s3files_mount_target" "s3fs_mnt_2" {
  file_system_id  = aws_s3files_file_system.s3fs.id
  subnet_id       = data.aws_subnet.ad_subnet.id
  security_groups = [aws_security_group.s3files_sg.id]
}
