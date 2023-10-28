resource "libvirt_volume" "source" {
  name   = "${var.vm}.qcow2"
  source = "/var/lib/libvirt/images/template.qcow2"
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

resource "libvirt_domain" "vm-virtual" {

  count = var.interface == "virtual" ? 1 : 0
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
    network_name = "default"
    wait_for_lease = true
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

resource "libvirt_domain" "vm-direct" {

  count = var.interface != "virtual" ? 1 : 0
  name = var.vm
  memory = var.mem
  vcpu = var.cpu
  qemu_agent = true

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.volume.id
  }

  network_interface {
    macvtap = var.interface
    mac = var.mac
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

resource "null_resource" "vm-direct-network" {

count = var.interface != "virtual" ? 1 : 0

provisioner "local-exec" {
  command = <<EOF
    sleep 20 ; virsh qemu-agent-command ${var.vm} '{"execute":"guest-exec", "arguments":{"path":"/bin/sh", "arg":["-c", "echo '\''auto lo eth0\niface lo inet loopback'\'' > /etc/network/interfaces"]}}'
    virsh qemu-agent-command ${var.vm} '{"execute":"guest-exec", "arguments":{"path":"/bin/sh", "arg":["-c", "echo '\''allow-hotplug eth0\niface eth0 inet static\naddress ${var.ip}\nnetmask 255.255.255.0\ngateway ${var.gateway}'\'' >> /etc/network/interfaces"]}}'
    virsh qemu-agent-command ${var.vm} '{"execute":"guest-exec", "arguments":{"path":"/bin/sh", "arg":["-c", "systemctl restart networking"]}}'
    virsh qemu-agent-command ${var.vm} '{"execute":"guest-exec", "arguments":{"path":"/bin/sh", "arg":["-c", "echo '\''nameserver 8.8.8.8'\'' > /etc/resolv.conf"]}}'
    virsh qemu-agent-command ${var.vm} '{"execute":"guest-exec", "arguments":{"path":"/bin/sh", "arg":["-c", "sleep 5 ; ifup eth0"]}}'
  EOF
}
  depends_on = [
    libvirt_domain.vm-direct
  ]

}
