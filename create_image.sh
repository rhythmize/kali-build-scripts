#!/bin/bash

if [ $EUID -ne 0 ];then
	echo "This script must be run as root"
	exit 1
fi

hostname="kali-rolling"
fs_dir="kali-fs"
uboot_dir="u-boot"
kernel_dir="linux"
mirror="https://http.kali.org/kali"
basedir=$(pwd)
machine=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

set -eu pipefail

# create filesystem
echo "Running debootstrap ..."
debootstrap --foreign --keyring=/usr/share/keyrings/kali-archive-keyring.gpg --include=kali-archive-keyring --arch armhf kali-rolling ${fs_dir} ${mirror}
cp /usr/bin/qemu-arm-static ${fs_dir}/usr/bin/
echo "Running debootstrap second stage ..."
systemd-nspawn -M ${machine} -D ${fs_dir}/ /debootstrap/debootstrap --second-stage

# install required packages
cp config_target.sh ${fs_dir}/

# use host system resolv.conf for dns resolution
systemd-nspawn -M ${machine} --bind /etc/resolv.conf:/etc/resolv.conf -D ${fs_dir}/ /config_target.sh
rm ${fs_dir}/config_target.sh

# Update hostname
echo "Updating hostname ..."
cat << EOF > ${fs_dir}/etc/hostname
${hostname}
EOF

# Update network interfaces
echo "Updating network interfaces ..."
cat << EOF > ${fs_dir}/etc/network/interfaces

# Local loopback
auto lo
iface lo inet loopback

# Wired adapter #1
allow-hotplug eth0
no-auto-down eth0
iface eth0 inet dhcp
EOF

# Update nameserver
echo "Updating nameserver ..."
cat << EOF > ${fs_dir}/etc/resolv.conf
nameserver 8.8.8.8
EOF


# create image file
echo "Creating image file ..."
dd if=/dev/zero of=${hostname}.img bs=1M count=2000 status=progress
# create partition
fdisk ${hostname}.img << EOF
n
p
1
2048

a
p
w

EOF

# associate loop device
loop_device=`losetup -f --show ${hostname}.img`
# inform os for partition table
partprobe ${loop_device}
# create filesystem
mkfs.ext4 ${loop_device}p1


# mount loop-device 
mount -o loop ${loop_device}p1 /mnt
# sync file system files with mount dir
echo "Syncing file system..."
rsync -HPavz -q ${basedir}/${fs_dir}/ /mnt
# unmount loop-device
umount /mnt
# desociate loop-device from image file
losetup -d ${loop_device}

echo "Image successfully saved in ${hostname}.img"
