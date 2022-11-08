#!/bin/bash

apt update ; apt install -y gdisk parted curl ca-certificates systemd-timesyncd
projects=std-vars
mkdir ${projects} && curl -o ${projects}/${projects}.sh https://raw.githubusercontent.com/lnomine/${projects}/master/${projects}.sh
source std-vars/std-vars.sh

### no swap please
swapoff -a
wipefs --all -f /dev/${disk}2
sgdisk -d 2 /dev/${disk}
partprobe /dev/${disk}
sed -i '/swap/d' /etc/fstab

### what time is it ?
echo "[Time]" > /etc/systemd/timesyncd.conf
echo "NTP=fr.pool.ntp.org" >> /etc/systemd/timesyncd.conf
timedatectl set-ntp true

### no more passwords
sed -Ei "s/^#?PermitRootLogin .+/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config
mkdir /root/.ssh
echo $rootpubrsa > /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
systemctl restart sshd

### regular sources
echo "deb http://deb.debian.org/debian bullseye main contrib non-free" > /etc/apt/sources.list
echo "deb http://security.debian.org/debian-security bullseye-security main contrib non-free" >> /etc/apt/sources.list
echo "deb http://deb.debian.org/debian bullseye-updates main contrib non-free" >> /etc/apt/sources.list

### no more debconf static/hacked
grep dhclient /etc/crontab
if [ $? -eq 0 ];
then
sed -i '/dhclient/d' /etc/crontab
echo "auto lo" > /etc/network/interfaces
echo "iface lo inet loopback" >> /etc/network/interfaces
echo "auto $interface" >> /etc/network/interfaces
echo "iface $interface inet static" >> /etc/network/interfaces
echo "address $ip" >> /etc/network/interfaces
echo "netmask $netmask" >> /etc/network/interfaces
echo "gateway $gateway" >> /etc/network/interfaces
echo "dns-nameservers $dns" >> /etc/network/interfaces
pkill dhclient
ip addr del ${link} dev ${interface} ; systemctl restart networking
fi

#cleanup
rm -r /root/*
