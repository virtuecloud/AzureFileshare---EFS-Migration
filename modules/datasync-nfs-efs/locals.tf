locals {
  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      Application = var.application
      CostCenter  = var.cost_center
      ManagedBy   = "terraform"
    }
  )

  name_prefix = "${var.project_name}-${var.environment}"
}
