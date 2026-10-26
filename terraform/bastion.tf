
resource "aws_instance" "bastion" {
  ami                         = var.mongodb_ami_id
  instance_type               = "t2.micro"
  key_name                    = "mongodb-aws-key"
  subnet_id                   = aws_subnet.mongodb[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "mongodb-bastion"
    Role = "bastion"
  }
}
