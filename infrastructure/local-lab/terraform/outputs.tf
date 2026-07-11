output "master_ips" {
  description = "Master node IPs"
  value       = proxmox_vm_qemu.master[*].default_ipv4_address
}

output "worker_ips" {
  description = "Worker node IPs"
  value       = proxmox_vm_qemu.worker[*].default_ipv4_address
}
