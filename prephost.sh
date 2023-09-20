#!/bin/bash

### regular sources
echo "deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list
echo "deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list
echo "deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list

apt update ; apt install -y gdisk parted curl ca-certificates systemd-timesyncd
projects=debonair
mkdir ${projects} && curl -o ${projects}/vars.sh https://raw.githubusercontent.com/lnomine/${projects}/master/vars.sh
source debonair/vars.sh

### no swap please
swapoff -a
wipefs --all -f /dev/${disk}2
sgdisk -d 2 /dev/${disk}
partprobe /dev/${disk}
sed -i '/swap/d' /etc/fstab
rm /etc/initramfs-tools/conf.d/resume
update-initramfs -u

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

### role management, specific usage

/tmp/role.sh "$1"
