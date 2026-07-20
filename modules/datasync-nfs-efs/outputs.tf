output "agent_arn" {
  description = "ARN of the activated DataSync agent"
  value       = aws_datasync_agent.azure_nfs.arn
}

output "nfs_location_arns" {
  description = "ARNs of the NFS source locations, keyed by migration"
  value       = { for k, v in aws_datasync_location_nfs.source : k => v.arn }
}

output "efs_location_arns" {
  description = "ARNs of the EFS destination locations, keyed by migration"
  value       = { for k, v in aws_datasync_location_efs.destination : k => v.arn }
}

output "task_arns" {
  description = "ARNs of the DataSync tasks, keyed by migration"
  value       = { for k, v in aws_datasync_task.this : k => v.arn }
}

output "kms_key_arn" {
  description = "KMS key ARN used for encryption"
  value       = local.kms_key_arn
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch log group ARN for DataSync task logs"
  value       = aws_cloudwatch_log_group.datasync.arn
}
