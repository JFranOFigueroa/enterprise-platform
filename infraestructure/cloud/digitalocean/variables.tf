variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "DigitalOcean SSH key name"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "enterprise-platform"
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc3"
}

variable "droplet_image" {
  description = "Droplet image"
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "droplet_size_server" {
  description = "Server droplet size"
  type        = string
  default     = "s-4vcpu-8gb"
}

variable "droplet_size_worker" {
  description = "Worker droplet size"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "agent_count" {
  description = "Number of agent nodes"
  type        = number
  default     = 2
}
