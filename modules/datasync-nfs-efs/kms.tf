resource "aws_kms_key" "this" {
  count = var.create_kms_key ? 1 : 0

  description             = "${local.name_prefix} DataSync NFS-EFS encryption key"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.enable_key_rotation

  tags = local.common_tags
}

resource "aws_kms_alias" "this" {
  count = var.create_kms_key ? 1 : 0

  name          = "alias/${coalesce(var.kms_key_alias, "${local.name_prefix}-datasync-nfs-efs")}"
  target_key_id = aws_kms_key.this[0].key_id
}

locals {
  kms_key_arn = var.create_kms_key ? aws_kms_key.this[0].arn : var.existing_kms_key_arn
}
