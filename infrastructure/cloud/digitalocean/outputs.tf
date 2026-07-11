output "server_ip" {
  description = "Server public IP"
  value       = digitalocean_droplet.server.ipv4_address
}

output "agent_ips" {
  description = "Agent public IPs"
  value       = digitalocean_droplet.agent[*].ipv4_address
}
