aws_region   = "us-east-1"
project_name = "vision-bank"
environment  = "dev"

owner       = "platform-team"
application = "vision-bank-storage-migration"
cost_center = "5432"

tags = {
  Project     = "vision-bank"
  Environment = "dev"
  ManagedBy   = "terraform"
}

create_kms_key          = false
existing_kms_key_arn    = "arn:aws:kms:us-east-1:800309353105:key/2c361ec3-1609-4273-887e-dab1dae4bcc1"
kms_key_deletion_window = 30
enable_key_rotation     = true

log_retention_days = 365
log_level          = "TRANSFER"

task_mode              = "BASIC"
transfer_mode          = "CHANGED"
overwrite_mode         = "ALWAYS"
verify_mode            = "ONLY_FILES_TRANSFERRED" # use POINT_IN_TIME_CONSISTENT for real cutover runs
preserve_deleted_files = "PRESERVE"
posix_permissions      = "PRESERVE"
enable_task_report     = true

# S3 bucket used only to store DataSync task-report output 
task_report_s3_bucket_arn = "arn:aws:s3:::datasyncbuckett"

#############################################################
# Agent activation
#############################################################
# Use ONE of the two below.
# ip_address:      Terraform fetches the activation key itself via HTTP GET
#                   to the agent VM on port 80 (requires network reachability
#                   from wherever you run `terraform apply`).
# activation_key:   You fetch the key manually from the agent's local console
#                   and paste it here instead.

agent_ip_address     = null # e.g. your Azure agent VM's public IP, "20.218.121.126"
agent_activation_key = "8G9MH-3AQ0V-UDGQ3-I03IM-9JJKR"

#############################################################
# Networking (cross-stack values from the whole-infra project)
#############################################################
# Get these with:
#   terraform output vpc_id                     (from dev/ project)
#   aws efs describe-mount-target-security-groups --file-system-id <id> (to get the EFS SG)

vpc_id                = "vpc-0c216eec185e58929"
efs_security_group_id = "sg-0325e4ef4e21a3241"

#############################################################
# Migrations
#############################################################

migrations = {
  nfs-to-efs-poc = {
    nfs_server_hostname = "efsmigration01.file.core.windows.net"
    nfs_subdirectory    = "/efsmigration01/nfsshare1"

    efs_file_system_arn = "arn:aws:elasticfilesystem:us-east-1:800309353105:file-system/fs-0d3287e3c32854149"
    efs_subdirectory    = "/"

    subnet_arn = "arn:aws:ec2:us-east-1:800309353105:subnet/subnet-0e869a5840ef9f5d4"

    task_report_subdirectory = "/datasync-reports/nfs-to-efs-poc"
  }

  # nfs-to-efs-poc2 = {
  #   nfs_server_hostname = "10.2.0.5"
  #   nfs_subdirectory    = "/efsmigration01/nfsshare2"

  #   efs_file_system_arn = "arn:aws:elasticfilesystem:us-east-1:800309353105:file-system/fs-0216c3e1072cba464"
  #   efs_subdirectory    = "/mnt/efs"

  #   subnet_arn = "arn:aws:ec2:us-east-1:800309353105:subnet/subnet-0e869a5840ef9f5d4"

  #   task_report_subdirectory = "/datasync-reports/nfs-to-efs-poc"
  # }
}
