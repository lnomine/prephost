#!/bin/bash

version="1.4.6"
target="terraform_${version}_linux_amd64.zip"

apt update ; apt install --install-recommends screen unzip curl iptables-persistent cockpit cockpit-machines -y
cd /usr/local/bin || exit ; curl -LO https://releases.hashicorp.com/terraform/${version}/${target}
unzip ${target} && rm -r ${target}
chmod +x terraform
virsh net-undefine default

### Uncomment if the host isn't fresh
#until virsh net-destroy default ; virsh pool-undefine default ; virsh pool-destroy default; do
#echo "Removing default settings..."
#done

cat <<- 'EOF' > /etc/libvirt/hooks/qemu
#!/bin/bash

export env VMNAME=${1}
screen -dmS ip bash -c "sleep 20 ; virsh domifaddr ${1} | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' > /etc/${1}"

source /etc/dynrules.sh

if [ -z "$GUEST_PORT" ]
then
exit 0
fi

if [ "${2}" = "stopped" ] || [ "${2}" = "reconnect" ]; then
export GUEST_IP=$(cat /etc/${1})
export interface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')
iptables -t nat -D PREROUTING -i ${interface} $RESTRICT $HOST_PORT -j DNAT --to ${GUEST_IP}${GUEST_PORT}
fi

if [ "${2}" = "start" ] || [ "${2}" = "reconnect" ]; then
export interface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')
screen -dmS nat bash -c 'sleep 25 ; export GUEST_IP=$(cat /etc/${VMNAME}) ; iptables -t nat -I PREROUTING -i ${interface} $RESTRICT $HOST_PORT -j DNAT --to ${GUEST_IP}${GUEST_PORT}'
fi
EOF

chmod +x /etc/libvirt/hooks/qemu
sed -i 's/#security_driver = "selinux"/security_driver = "none"/g' /etc/libvirt/qemu.conf && systemctl restart libvirtd

cd -
terraform init && terraform apply --auto-approve
