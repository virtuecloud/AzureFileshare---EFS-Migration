#############################
# General
#############################

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment"
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "owner" {
  description = "Application owner"
  type        = string
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

#############################
# KMS
#############################

variable "existing_kms_key_arn" {
  description = "Existing KMS Key ARN"
  type        = string
  default     = null

  validation {
    condition = (
      var.existing_kms_key_arn == null ||
      can(regex("^arn:aws:kms:", var.existing_kms_key_arn))
    )
    error_message = "existing_kms_key_arn must be a valid AWS KMS ARN."
  }
}

variable "create_kms_key" {
  type        = bool
  description = "Create KMS Key"
  default     = true
}

variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30

  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}

variable "enable_key_rotation" {
  type    = bool
  default = true
}

variable "kms_key_alias" {
  description = "Alias for a newly created KMS key (without the alias/ prefix)"
  type        = string
  default     = null
}

#############################
# CloudWatch
#############################

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 365

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90,
      120, 150, 180, 365, 400,
      545, 731, 1096, 1827, 2192,
      2557, 2922, 3288, 3653
    ], var.log_retention_days)
    error_message = "Use a valid CloudWatch Logs retention period."
  }
}

variable "log_level" {
  description = "DataSync log level"
  type        = string
  default     = "TRANSFER"

  validation {
    condition     = contains(["OFF", "BASIC", "TRANSFER"], var.log_level)
    error_message = "Valid values are OFF, BASIC or TRANSFER."
  }
}

#############################
# Task options
#############################

variable "task_mode" {
  type    = string
  default = "ENHANCED"

  validation {
    condition     = contains(["BASIC", "ENHANCED"], var.task_mode)
    error_message = "Valid values are BASIC or ENHANCED."
  }
}

variable "posix_permissions" {
  type    = string
  default = "PRESERVE"
}

variable "transfer_mode" {
  type    = string
  default = "CHANGED"

  validation {
    condition     = contains(["ALL", "CHANGED"], var.transfer_mode)
    error_message = "Valid values are ALL or CHANGED."
  }
}

variable "overwrite_mode" {
  type    = string
  default = "ALWAYS"

  validation {
    condition     = contains(["ALWAYS", "NEVER"], var.overwrite_mode)
    error_message = "Valid values are ALWAYS or NEVER."
  }
}

variable "verify_mode" {
  description = "Verification mode for DataSync task"
  type        = string
  default     = "POINT_IN_TIME_CONSISTENT"

  validation {
    condition = contains([
      "NONE",
      "ONLY_FILES_TRANSFERRED",
      "POINT_IN_TIME_CONSISTENT"
    ], var.verify_mode)
    error_message = "Valid values are NONE, ONLY_FILES_TRANSFERRED or POINT_IN_TIME_CONSISTENT."
  }
}

variable "preserve_deleted_files" {
  description = "Preserve or remove deleted files at destination"
  type        = string
  default     = "PRESERVE"

  validation {
    condition = contains([
      "PRESERVE",
      "REMOVE"
    ], var.preserve_deleted_files)
    error_message = "Valid values are PRESERVE or REMOVE."
  }
}

variable "enable_task_report" {
  description = "Enable DataSync task reports"
  type        = bool
  default     = true
}

variable "task_report_s3_bucket_arn" {
  description = "S3 bucket ARN used to store DataSync task reports (not the migration destination, just the report output)"
  type        = string
}

#############################
# Agent
#############################

variable "agent_ip_address" {
  description = "Public or reachable IP address of the DataSync agent VM (Azure) used for activation. Leave null if supplying activation_key instead."
  type        = string
  default     = null
}

variable "agent_activation_key" {
  description = "Activation key retrieved manually from the agent's local console/API. Leave null if supplying agent_ip_address instead."
  type        = string
  default     = null
  sensitive = true

  validation {
    condition     = var.agent_ip_address != null || var.agent_activation_key != null
    error_message = "One of agent_ip_address or agent_activation_key must be provided."
  }
}

#############################
# Networking (cross-stack references into whole-infra)
#############################

variable "vpc_id" {
  description = "VPC ID (same VPC as the EFS mount targets) where the DataSync security group will be created"
  type        = string
}

variable "efs_security_group_id" {
  description = "Security group ID already attached to the EFS mount targets in the whole-infra project. Terraform will add an ingress rule to it here."
  type        = string
}

#############################
# Migrations
#############################

variable "migrations" {
  description = "Map of Azure NFS to Amazon EFS DataSync migrations."

  type = map(object({
    nfs_server_hostname = string
    nfs_subdirectory    = string

    efs_file_system_arn = string
    efs_subdirectory    = optional(string, "/")

    subnet_arn = string

    task_report_subdirectory = optional(string, "/datasync-reports")
  }))

  validation {
    condition = alltrue([
      for migration in values(var.migrations) :
      startswith(migration.nfs_subdirectory, "/")
    ])
    error_message = "Each NFS subdirectory must start with '/'."
  }

  validation {
    condition = alltrue([
      for migration in values(var.migrations) :
      startswith(migration.efs_subdirectory, "/")
    ])
    error_message = "Each EFS subdirectory must start with '/'."
  }

  validation {
    condition = alltrue([
      for migration in values(var.migrations) :
      can(regex("^arn:aws:elasticfilesystem:", migration.efs_file_system_arn))
    ])
    error_message = "Each efs_file_system_arn must be a valid EFS ARN."
  }

  validation {
    condition = alltrue([
      for migration in values(var.migrations) :
      startswith(migration.task_report_subdirectory, "/")
    ])
    error_message = "Each task report subdirectory must start with '/'."
  }
}
