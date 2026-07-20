resource "aws_cloudwatch_log_group" "datasync" {
  name              = "/aws/datasync"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.kms_key_arn

  tags = local.common_tags
}

# DataSync requires a resource policy on the log group allowing the service to write to it.
data "aws_iam_policy_document" "datasync_log_policy" {
  statement {
    sid    = "DataSyncLogsAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["datasync.amazonaws.com"]
    }

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "${aws_cloudwatch_log_group.datasync.arn}:*",
    ]
  }
}

resource "aws_cloudwatch_log_resource_policy" "datasync" {
  policy_name     = "${local.name_prefix}-datasync-nfs-efs-logs"
  policy_document = data.aws_iam_policy_document.datasync_log_policy.json
}
