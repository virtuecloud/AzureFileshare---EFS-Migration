data "aws_iam_policy_document" "datasync_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["datasync.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "datasync" {
  name               = "${local.name_prefix}-datasync-nfs-efs-role"
  assume_role_policy = data.aws_iam_policy_document.datasync_assume_role.json

  tags = local.common_tags
}

# Note: unlike S3, EFS access for DataSync is network-based (via the ENI that
# DataSync creates in the subnet/security group you specify), not IAM-based.
# This role is only needed for: task report delivery to S3, and KMS key usage.

data "aws_iam_policy_document" "datasync_permissions" {
  statement {
    sid    = "TaskReportS3Access"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]

    resources = [
      var.task_report_s3_bucket_arn,
      "${var.task_report_s3_bucket_arn}/*",
    ]
  }

  statement {
    sid    = "KmsUsage"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]

    resources = [local.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "datasync" {
  name   = "${local.name_prefix}-datasync-nfs-efs-policy"
  role   = aws_iam_role.datasync.id
  policy = data.aws_iam_policy_document.datasync_permissions.json
}

resource "time_sleep" "wait_for_iam" {
  depends_on      = [aws_iam_role_policy.datasync]
  create_duration = "10s"
}
