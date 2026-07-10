terraform {
  required_version = ">= 1.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_ssh_key" "default" {
  name = var.ssh_key_name
}

resource "digitalocean_droplet" "server" {
  name   = "${var.project_name}-server-01"
  region = var.region
  size   = var.droplet_size_server
  image  = var.droplet_image
  ssh_keys = [data.digitalocean_ssh_key.default.id]

  tags = ["enterprise-platform", "server"]
}

resource "digitalocean_droplet" "agent" {
  count  = var.agent_count
  name   = "${var.project_name}-agent-0${count.index + 1}"
  region = var.region
  size   = var.droplet_size_worker
  image  = var.droplet_image
  ssh_keys = [data.digitalocean_ssh_key.default.id]

  tags = ["enterprise-platform", "agent"]
}

resource "digitalocean_firewall" "rke2" {
  name = "${var.project_name}-rke2"

  inbound_rule {
    protocol    = "tcp"
    port_range  = "22"
    source_addresses = ["0.0.0.0/0"]
  }

  inbound_rule {
    protocol    = "tcp"
    port_range  = "6443"
    source_addresses = ["0.0.0.0/0"]
  }

  inbound_rule {
    protocol    = "tcp"
    port_range  = "2379-2380"
    source_addresses = ["10.0.0.0/8"]
  }

  inbound_rule {
    protocol    = "udp"
    port_range  = "8472"
    source_addresses = ["10.0.0.0/8"]
  }

  inbound_rule {
    protocol    = "udp"
    port_range  = "4789"
    source_addresses = ["10.0.0.0/8"]
  }

  inbound_rule {
    protocol    = "udp"
    port_range  = "51820"
    source_addresses = ["0.0.0.0/0"]
  }

  inbound_rule {
    protocol    = "tcp"
    port_range  = "30000-32767"
    source_addresses = ["0.0.0.0/0"]
  }

  droplet_ids = [digitalocean_droplet.server.id, digitalocean_droplet.agent[*].id]
}
