
resource "aws_instance" "mongodb" {
  count = 3

  ami                         = var.mongodb_ami_id
  instance_type               = var.mongodb_instance_type
  key_name                    = "mongodb-aws-key"
  subnet_id                   = aws_subnet.private[count.index].id
  vpc_security_group_ids      = [aws_security_group.mongodb.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  associate_public_ip_address = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gib
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "mongo-cs${count.index + 1}-root"
    }
  }

  tags = {
    Name = "mongo-cs${count.index + 1}"
    Role = "replica-set-member"
  }
}
