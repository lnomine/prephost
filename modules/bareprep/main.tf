variable tplhost {}
variable vm {}
variable disksize {}
variable cpu {}
variable mem {}
variable ip {}

terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "0.7.1"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_network" "open" {
  name = "default"
  mode = "open"
  addresses = ["192.168.122.0/24"]
  dhcp {
   enabled = true
  }

 provisioner "local-exec" {
  command = "cd /var/lib/libvirt/images/ ; curl -LO http://${var.tplhhost}/template.qcow2"
  }
}

resource "libvirt_pool" "default" {
  name = "default"
  type = "dir"
  path = "/var/lib/libvirt/images"
}

resource "libvirt_volume" "source" {
  name   = "${var.vm}.qcow2"
  source = "/var/lib/libvirt/images/template.qcow2"

  depends_on = [
    libvirt_network.open,libvirt_pool.default
  ]
}

resource "libvirt_volume" "volume" {
  name = "${var.vm}.qcow2"
  base_volume_id = libvirt_volume.source.id

  depends_on = [
    libvirt_volume.source
  ]
}

resource "null_resource" "resize" {
 provisioner "local-exec" {
  command = "qemu-img resize /var/lib/libvirt/images/${var.vm}.qcow2 +${var.disksize -2}G"
  }

  depends_on = [
    libvirt_volume.volume
  ]
}

resource "libvirt_domain" "vm" {
  name = var.vm
  memory = var.mem
  vcpu = var.cpu

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.volume.id
  }

  network_interface {
    network_name = libvirt_network.open.name
    hostname       = var.vm
    addresses      = var.ip
  }

  graphics {
    type = "vnc"
    listen_type = "address"
    websocket = "-1"
  }

  depends_on = [
    null_resource.resize
  ]
}

resource "null_resource" "routing" {
  provisioner "local-exec" {
    command = "iptables -t nat -A POSTROUTING -j MASQUERADE && sysctl -w net.ipv6.conf.all.disable_ipv6=1"
  }
}
