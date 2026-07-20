module "datasync_nfs_efs" {

  source = "./modules/datasync-nfs-efs"

  aws_region   = var.aws_region
  project_name = var.project_name
  environment  = var.environment

  owner       = var.owner
  application = var.application
  cost_center = var.cost_center

  tags = var.tags

  create_kms_key       = var.create_kms_key
  existing_kms_key_arn = var.existing_kms_key_arn
  kms_key_deletion_window = var.kms_key_deletion_window
  enable_key_rotation     = var.enable_key_rotation
  kms_key_alias           = var.kms_key_alias

  migrations = var.migrations

  task_mode              = var.task_mode
  transfer_mode          = var.transfer_mode
  overwrite_mode         = var.overwrite_mode
  verify_mode            = var.verify_mode
  preserve_deleted_files = var.preserve_deleted_files
  log_level              = var.log_level
  posix_permissions      = var.posix_permissions

  log_retention_days = var.log_retention_days

  enable_task_report        = var.enable_task_report
  task_report_s3_bucket_arn = var.task_report_s3_bucket_arn

  agent_ip_address      = var.agent_ip_address
  agent_activation_key  = var.agent_activation_key

  vpc_id                 = var.vpc_id
  efs_security_group_id  = var.efs_security_group_id
}
