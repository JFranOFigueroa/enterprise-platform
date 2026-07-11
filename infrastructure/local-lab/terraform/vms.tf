resource "proxmox_vm_qemu" "master" {
  count       = var.master_count
  name        = "${var.project_name}-master-0${count.index + 1}"
  target_node = var.proxmox_node
  vmid        = 9001 + count.index
  clone       = var.template_id

  cores    = var.master_cpu
  memory   = var.master_memory
  cpu_type = "host"

  disk {
    size    = var.disk_size
    type    = "scsi"
    storage = "local-lvm"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  os_type = "cloud-init"
  ipconfig0 = "ip=192.168.0.${10 + count.index}/24,gw=192.168.0.1"

  sshkeys = var.ssh_public_key
}

resource "proxmox_vm_qemu" "worker" {
  count       = var.worker_count
  name        = "${var.project_name}-worker-0${count.index + 1}"
  target_node = var.proxmox_node
  vmid        = 9101 + count.index
  clone       = var.template_id

  cores    = var.worker_cpu
  memory   = var.worker_memory
  cpu_type = "host"

  disk {
    size    = var.disk_size
    type    = "scsi"
    storage = "local-lvm"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  os_type = "cloud-init"
  ipconfig0 = "ip=192.168.0.${20 + count.index}/24,gw=192.168.0.1"

  sshkeys = var.ssh_public_key
}

variable "ssh_public_key" {
  description = "SSH public key for cloud-init"
  type        = string
}
