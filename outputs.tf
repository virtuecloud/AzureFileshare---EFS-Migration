output "agent_arn" {
  description = "ARN of the activated DataSync agent"
  value       = module.datasync_nfs_efs.agent_arn
}

output "nfs_location_arns" {
  description = "ARNs of the NFS source locations, keyed by migration"
  value       = module.datasync_nfs_efs.nfs_location_arns
}

output "efs_location_arns" {
  description = "ARNs of the EFS destination locations, keyed by migration"
  value       = module.datasync_nfs_efs.efs_location_arns
}

output "task_arns" {
  description = "ARNs of the DataSync tasks, keyed by migration"
  value       = module.datasync_nfs_efs.task_arns
}
