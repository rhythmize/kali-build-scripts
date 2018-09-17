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

# configure target filesystem
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

# Build linux-kernel
echo "Building Linux kernel ..."
cd ${kernel_dir}
make ARCH=arm sunxi_defconfig
make -j $(grep -c processor /proc/cpuinfo) ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs
make -j $(grep -c processor /proc/cpuinfo) ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules
# install kernel modules
echo "Installing kernel modules ..."
make -j $(grep -c processor /proc/cpuinfo) ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=${basedir}/${fs_dir}/ modules_install
# copy kernel image and device tree

echo "Copying kernel image and device tree ..."
cp arch/arm/boot/zImage ${basedir}/${fs_dir}/boot/
cp arch/arm/boot/dts/sun8i-h2-plus-libretech-all-h3-cc.dtb ${basedir}/${fs_dir}/boot/device_tree.dtb
# clear repository
make mrproper
cd ${basedir}

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

# Build u-boot
echo "Building U-Boot bootloader ..."
cd ${uboot_dir}
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- libretech_all_h3_cc_h2_plus_defconfig
# PATCH: needed to do it for my board for u-boot to read kernel and device-tree 
sed -i 's/CONFIG_ENV_FAT_DEVICE_AND_PART=.*/CONFIG_ENV_FAT_DEVICE_AND_PART="0:auto"/g' .config
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-

# create boot.cmd file
cat << 'EOF' > ${basedir}/${fs_dir}/boot/boot.cmd
setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p1 rootwait panic=10 rw rootfstype=ext4 net.ifnames=0
load mmc 0:1 $kernel_addr_r /boot/zImage
load mmc 0:1 $fdt_addr_r /boot/device_tree.dtb
bootz $kernel_addr_r - $fdt_addr_r
EOF

# Create u-boot boot script image
echo "Creating u-boot boot script ..."
mkimage -A arm -T script -C none -d ${basedir}/${fs_dir}/boot/boot.cmd ${basedir}/${fs_dir}/boot/boot.scr

# flash u-boot
echo "Flashing u-boot ..."
dd if=u-boot-sunxi-with-spl.bin of=${loop_device} bs=1024 seek=8 status=progress
# clear repository
make mrproper
cd ${basedir}

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