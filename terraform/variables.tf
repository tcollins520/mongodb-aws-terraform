
variable "aws_region" {
  description = "AWS region for the MongoDB replica-set project."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project tag and resource naming prefix."
  type        = string
  default     = "mongodb-aws"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "replica-set"
}

variable "vpc_cidr" {
  description = "Dedicated project VPC CIDR."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones for the three replica-set nodes."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]

  validation {
    condition     = length(var.availability_zones) == 3
    error_message = "Exactly three Availability Zones must be provided."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs across three Availability Zones."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.20.0/24", "10.20.30.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 3
    error_message = "Exactly three public subnet CIDRs must be provided."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for the MongoDB replica-set nodes."
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.21.0/24", "10.20.31.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 3
    error_message = "Exactly three private subnet CIDRs must be provided."
  }
}

variable "mongodb_instance_type" {
  description = "EC2 instance type for each MongoDB replica-set member."
  type        = string
  default     = "t2.micro"
}

variable "root_volume_size_gib" {
  description = "Encrypted gp3 root volume size in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size_gib >= 20
    error_message = "The root volume must be at least 20 GiB."
  }
}

variable "mongodb_ami_id" {
  description = "Pinned official Red Hat Enterprise Linux 8.10 x86-64 AMI."
  type        = string
  default     = "ami-03288f7877c413c29"
}
