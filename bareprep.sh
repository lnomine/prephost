#!/bin/bash

version="1.4.6"
target="terraform_${version}_linux_amd64.zip"

apt update ; apt install unzip curl cockpit cockpit-machines -y
cd /usr/local/bin || exit ; curl -LO https://releases.hashicorp.com/terraform/${version}/${target}
unzip ${target} && rm -r ${target}
chmod +x terraform
virsh net-undefine default
sed -i 's/#security_driver = "selinux"/security_driver = "none"/g' /etc/libvirt/qemu.conf && systemctl restart libvirtd

terraform init && terraform apply --auto-approve
