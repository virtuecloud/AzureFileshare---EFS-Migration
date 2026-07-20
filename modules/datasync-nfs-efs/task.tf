#############################################################
# Agent activation (Azure-hosted DataSync agent)
#############################################################
# The agent VM itself is deployed OUTSIDE Terraform (Azure VM,
# via the aws-datasync-deploy-agent-azure script or manually).
# This resource only performs the AWS-side activation.

resource "aws_datasync_agent" "azure_nfs" {
  ip_address     = var.agent_ip_address
  activation_key = var.agent_activation_key

  name = "${local.name_prefix}-azure-nfs-agent"
  tags = local.common_tags
}

#############################################################
# NFS Locations (Azure source)
#############################################################

resource "aws_datasync_location_nfs" "source" {
  for_each = var.migrations

  server_hostname = each.value.nfs_server_hostname
  subdirectory    = each.value.nfs_subdirectory

  on_prem_config {
    agent_arns = [aws_datasync_agent.azure_nfs.arn]
  }

  mount_options {
    version = "NFS4_1"
  }

  tags = local.common_tags
}

#############################################################
# EFS Locations (AWS destination)
#############################################################

resource "aws_datasync_location_efs" "destination" {
  for_each = var.migrations

  efs_file_system_arn = each.value.efs_file_system_arn
  subdirectory         = each.value.efs_subdirectory

  ec2_config {
    subnet_arn           = each.value.subnet_arn
    security_group_arns  = [aws_security_group.datasync.arn]
  }

  in_transit_encryption = "TLS1_2"

  tags = local.common_tags

  depends_on = [
    aws_cloudwatch_log_resource_policy.datasync,
    aws_vpc_security_group_ingress_rule.efs_allow_datasync,
  ]
}

#############################################################
# DataSync Tasks
#############################################################

resource "aws_datasync_task" "this" {
  for_each = var.migrations

  name = "${var.project_name}-${var.environment}-${each.key}"

  source_location_arn      = aws_datasync_location_nfs.source[each.key].arn
  destination_location_arn = aws_datasync_location_efs.destination[each.key].arn

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.datasync.arn

  task_mode = var.task_mode

  options {
    transfer_mode          = var.transfer_mode
    overwrite_mode         = var.overwrite_mode
    verify_mode            = var.verify_mode
    preserve_deleted_files = var.preserve_deleted_files

    log_level         = var.log_level
    posix_permissions = var.posix_permissions

    uid = "NONE"
    gid = "NONE"
  }

  dynamic "task_report_config" {
    for_each = var.enable_task_report ? [1] : []

    content {
      output_type  = "STANDARD"
      report_level = "ERRORS_ONLY"

      s3_destination {
        s3_bucket_arn          = var.task_report_s3_bucket_arn
        bucket_access_role_arn = aws_iam_role.datasync.arn
        subdirectory            = each.value.task_report_subdirectory
      }
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_datasync_location_nfs.source,
    aws_datasync_location_efs.destination,
    time_sleep.wait_for_iam,
  ]
}
