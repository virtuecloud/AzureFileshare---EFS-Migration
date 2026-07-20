#############################################################
# Dedicated security group for DataSync's ENIs
#############################################################

resource "aws_security_group" "datasync" {
  name        = "${local.name_prefix}-datasync-nfs-efs-sg"
  description = "DataSync ENIs for Azure NFS to EFS migration"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-datasync-nfs-efs-sg"
  })
}

resource "aws_vpc_security_group_egress_rule" "datasync_all_outbound" {
  security_group_id = aws_security_group.datasync.id
  description       = "Allow all outbound (DataSync control plane and NFS/EFS data plane)"
  ip_protocol        = "-1"
  cidr_ipv4           = "0.0.0.0/0"
}

#############################################################
# Ingress rule on the EXISTING EFS security group
# (EFS itself is managed in the whole-infra project's state;
#  we only add a rule here, we do not own that SG's lifecycle)
#############################################################

resource "aws_vpc_security_group_ingress_rule" "efs_allow_datasync" {
  security_group_id = var.efs_security_group_id
  description        = "Allow NFS from DataSync ENIs (Azure NFS to EFS migration)"
  ip_protocol         = "tcp"
  from_port            = 2049
  to_port               = 2049
  referenced_security_group_id = aws_security_group.datasync.id
}
