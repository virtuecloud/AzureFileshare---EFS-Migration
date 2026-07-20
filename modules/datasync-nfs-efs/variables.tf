variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "owner" {
  type = string
}

variable "application" {
  type = string
}

variable "cost_center" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "create_kms_key" {
  type    = bool
  default = true
}

variable "existing_kms_key_arn" {
  type    = string
  default = null
}

variable "kms_key_deletion_window" {
  type    = number
  default = 30
}

variable "enable_key_rotation" {
  type    = bool
  default = true
}

variable "kms_key_alias" {
  type    = string
  default = null
}

variable "log_retention_days" {
  type    = number
  default = 365
}

variable "log_level" {
  type    = string
  default = "TRANSFER"
}

variable "task_mode" {
  type    = string
  default = "ENHANCED"
}

variable "posix_permissions" {
  type    = string
  default = "PRESERVE"
}

variable "transfer_mode" {
  type    = string
  default = "CHANGED"
}

variable "overwrite_mode" {
  type    = string
  default = "ALWAYS"
}

variable "verify_mode" {
  type    = string
  default = "POINT_IN_TIME_CONSISTENT"
}

variable "preserve_deleted_files" {
  type    = string
  default = "PRESERVE"
}

variable "enable_task_report" {
  type    = bool
  default = true
}

variable "task_report_s3_bucket_arn" {
  type = string
}

variable "agent_ip_address" {
  type    = string
  default = null
}

variable "agent_activation_key" {
  type    = string
  default = null
}

variable "vpc_id" {
  description = "VPC ID where the DataSync security group will be created (must be the same VPC as the EFS mount targets)"
  type        = string
}

variable "efs_security_group_id" {
  description = "Security group ID already attached to the EFS mount targets (from the whole-infra EFS module). A rule allowing DataSync will be added to it."
  type        = string
}

variable "migrations" {
  type = map(object({
    nfs_server_hostname = string
    nfs_subdirectory    = string

    efs_file_system_arn = string
    efs_subdirectory    = optional(string, "/")

    subnet_arn = string

    task_report_subdirectory = optional(string, "/datasync-reports")
  }))
}
