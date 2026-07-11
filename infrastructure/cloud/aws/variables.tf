variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "enterprise-platform"
}

variable "ssh_key_name" {
  description = "AWS key pair name"
  type        = string
}

variable "instance_type_server" {
  description = "Server instance type"
  type        = string
  default     = "m5.xlarge"
}

variable "instance_type_worker" {
  description = "Worker instance type"
  type        = string
  default     = "m5.large"
}

variable "agent_count" {
  description = "Number of agent nodes"
  type        = number
  default     = 2
}
