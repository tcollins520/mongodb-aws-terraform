
output "vpc_id" {
  description = "ID of the MongoDB project VPC."
  value       = aws_vpc.mongodb.id
}

output "vpc_cidr" {
  description = "CIDR block of the project VPC."
  value       = aws_vpc.mongodb.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the VPC Internet Gateway."
  value       = aws_internet_gateway.mongodb.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway for private subnet outbound access."
  value       = aws_nat_gateway.mongodb.id
}

output "mongodb_security_group_id" {
  description = "Security group ID for the MongoDB nodes."
  value       = aws_security_group.mongodb.id
}

output "ssm_instance_profile_name" {
  description = "IAM instance profile attached to MongoDB nodes."
  value       = aws_iam_instance_profile.ssm.name
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.mongodb[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "Availability Zones used by the private MongoDB subnets."
  value       = aws_subnet.private[*].availability_zone
}

output "mongodb_instance_ids" {
  description = "IDs of the three MongoDB instances."
  value       = aws_instance.mongodb[*].id
}

output "mongodb_private_ips" {
  description = "Private IP addresses of the MongoDB nodes."
  value       = aws_instance.mongodb[*].private_ip
}

output "bastion_instance_id" {
  description = "ID of the bastion instance."
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion."
  value       = aws_instance.bastion.public_ip
}
