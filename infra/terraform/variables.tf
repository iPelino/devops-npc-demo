variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the SSH key pair to use. Must match an existing key pair in AWS EC2. See docs/ssh_setup_guide.md for setup instructions."
  type        = string
  default     = "devops-demo-key" # Change this to your AWS key pair name or set TF_VAR_key_name
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance"
  type        = string
  default     = "0.0.0.0/0" # WARNING: Restrict this in production
}
