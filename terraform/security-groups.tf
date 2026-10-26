
resource "aws_security_group" "mongodb" {
  name_prefix = "${var.project_name}-mongodb-"
  description = "Restricted MongoDB replica-set network access."
  vpc_id      = aws_vpc.mongodb.id

  tags = {
    Name = "${var.project_name}-mongodb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "mongodb_cluster" {
  security_group_id            = aws_security_group.mongodb.id
  referenced_security_group_id = aws_security_group.mongodb.id

  description = "MongoDB traffic between replica-set members"
  from_port   = 27017
  to_port     = 27017
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "mongodb_cluster" {
  security_group_id            = aws_security_group.mongodb.id
  referenced_security_group_id = aws_security_group.mongodb.id

  description = "MongoDB traffic between replica-set members"
  from_port   = 27017
  to_port     = 27017
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.mongodb.id

  description = "HTTPS for package repositories and Systems Manager"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_security_group" "bastion" {
  name_prefix = "${var.project_name}-bastion-"
  description = "SSH entry point for MongoDB administration"
  vpc_id      = aws_vpc.mongodb.id

  ingress {
    description = "SSH from my current public IP"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["72.83.2.51/32"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_bastion" {
  security_group_id            = aws_security_group.mongodb.id
  referenced_security_group_id = aws_security_group.bastion.id
  description                  = "SSH from bastion host only"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_mongodb_ssh" {
  security_group_id            = aws_security_group.bastion.id
  referenced_security_group_id = aws_security_group.mongodb.id
  description                  = "SSH from bastion to MongoDB nodes"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}
