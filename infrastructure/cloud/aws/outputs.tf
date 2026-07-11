output "server_public_ip" {
  description = "Server public IP"
  value       = aws_instance.server.public_ip
}

output "server_private_ip" {
  description = "Server private IP"
  value       = aws_instance.server.private_ip
}

output "agent_public_ips" {
  description = "Agent public IPs"
  value       = aws_instance.agent[*].public_ip
}

output "agent_private_ips" {
  description = "Agent private IPs"
  value       = aws_instance.agent[*].private_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}
