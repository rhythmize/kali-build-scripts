#!/bin/bash

if [ $EUID -ne 0 ];then
	echo "This script must be run as root"
	exit 1
fi

BOLD=$(tput bold)
NORMAL=$(tput sgr0)
RED='\033[0;31m'
NC='\033[0m' # No Color

hostname="kali-rolling"
image_dir="images"
image_file="${image_dir}/${hostname}.img"
fs_dir="/tmp/kali-fs-`date +'%Y_%m_%d_%H_%M_%S'`"
uboot_dir="u-boot"
kernel_dir="linux"
firmware_dir="linux-firmware"
mirror="http://http.kali.org/kali"
basedir=$(pwd)
machine=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

set -euo pipefail

mkdir -p $image_dir

# create filesystem
echo -e "${RED}${BOLD}[+] Running debootstrap first stage ...${NORMAL}${NC}"
debootstrap --foreign --keyring=/usr/share/keyrings/kali-archive-keyring.gpg --include=kali-archive-keyring --arch armhf kali-rolling ${fs_dir} ${mirror}
echo -e "${RED}${BOLD}[+] Debootstrap first stage finished successfully${NORMAL}${NC}"

cp /usr/bin/qemu-arm-static ${fs_dir}/usr/bin/
echo -e "${RED}${BOLD}[+] Running debootstrap second stage ...${NORMAL}${NC}"
LANG=C systemd-nspawn -M ${machine} -D ${fs_dir}/ /debootstrap/debootstrap --second-stage
echo -e "${RED}${BOLD}[+] Debootstrap second stage finished successfully${NORMAL}${NC}"

# configure target filesystem
cp utils/config_target.sh ${fs_dir}/

# use host system resolv.conf for dns resolution
echo -e "${RED}${BOLD}[+] Configure target filesystem ...${NORMAL}${NC}"
LANG=C systemd-nspawn -M ${machine} --bind-ro /etc/resolv.conf -D ${fs_dir}/ /config_target.sh
echo -e "${RED}${BOLD}[+] Target filesystem configured successfully ...${NORMAL}${NC}"

rm ${fs_dir}/config_target.sh

# Update hostname
echo -e "${RED}${BOLD}Updating hostname ...${NORMAL}${NC}"
cat << EOF > ${fs_dir}/etc/hostname
${hostname}
EOF

# Update network interfaces
echo -e "${RED}${BOLD}Updating network interfaces ...${NORMAL}${NC}"
cat << EOF > ${fs_dir}/etc/network/interfaces

# Local loopback
auto lo
iface lo inet loopback

# Wired adapter #1
allow-hotplug eth0
no-auto-down eth0
iface eth0 inet dhcp

# Wireless adapter #1
# for in-built adapter change `allow-hotplug` to `auto`
allow-hotplug wlan0
iface wlan0 inet dhcp
pre-up wpa_supplicant -Dwext -i wlan0 -c /etc/wpa_supplicant.conf -B
EOF

# Update nameserver
echo -e "${RED}${BOLD}Updating nameserver ...${NORMAL}${NC}"
cat << EOF > ${fs_dir}/etc/resolv.conf
nameserver 8.8.8.8
EOF

# Build linux-kernel
if [ -d ${kernel_dir} ]; then
	echo -e "${RED}${BOLD}Building Linux kernel ...${NORMAL}${NC}"
	cd ${kernel_dir}
	make ARCH=arm sunxi_defconfig
	# copy kernel config file from archive
	cp ../archive/kernel/config/linux_4.18_config .config
	make -j $(grep -c processor /proc/cpuinfo) ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs
	make -j $(grep -c processor /proc/cpuinfo) ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules
	# install kernel modules
	echo -e "${RED}${BOLD}Installing currently build kernel and modules ...${NORMAL}${NC}"
	make -j $(grep -c processor /proc/cpuinfo) ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=${fs_dir}/ modules_install

	# copy kernel image and device tree
	cp arch/arm/boot/zImage ${fs_dir}/boot/
	cp arch/arm/boot/dts/sun8i-h2-plus-libretech-all-h3-cc.dtb ${fs_dir}/boot/device_tree.dtb
	# clear repository
	make mrproper
	cd ${basedir}
else
	echo -e "${RED}${BOLD}Installing kernel and modules from archive ...${NORMAL}${NC}"
	cp -r archive/kernel/lib/modules/ ${fs_dir}/lib/
	# copy kernel image and device tree from archive
	cp archive/kernel/boot/zImage ${fs_dir}/boot/
	cp archive/kernel/boot/device_tree.dtb ${fs_dir}/boot/
fi

if [ -d ${firmware_dir} ]; then
	echo -e "${RED}${BOLD}Copying RTL wifi firmware ...${NORMAL}${NC}"
	cp -r ${firmware_dir}/rtlwifi/ ${fs_dir}/lib/firmware/
fi

# create image file
echo -e "${RED}${BOLD}Creating image file ...${NORMAL}${NC}"
dd if=/dev/zero of=${image_file} bs=1M count=2000 status=progress
# create partition
fdisk ${image_file} << EOF
n
p
1
2048

a
p
w

EOF

# associate loop device
loop_device=`losetup -f --show ${image_file}`
# inform os for partition table
partprobe ${loop_device}
# create filesystem
mkfs.ext4 ${loop_device}p1

# Build u-boot, if u-boot directory exists
if [ -d ${uboot_dir} ]; then
	echo -e "${RED}${BOLD}Building U-Boot bootloader ...${NORMAL}${NC}"
	cd ${uboot_dir}
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- libretech_all_h3_cc_h2_plus_defconfig
	# PATCH: needed to do it for my board for u-boot to read kernel and device-tree 
	sed -i 's/CONFIG_ENV_FAT_DEVICE_AND_PART=.*/CONFIG_ENV_FAT_DEVICE_AND_PART="0:auto"/g' .config
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-

	echo -e "${RED}${BOLD}Flashing currently build u-boot ...${NORMAL}${NC}"
	dd if=u-boot-sunxi-with-spl.bin of=${loop_device} bs=1024 seek=8 status=progress
	# clear repository
	make mrproper
	cd ${basedir}
else
	echo -e "${RED}${BOLD}Flashing u-boot from archive ...${NORMAL}${NC}"
	dd if=archive/u-boot/u-boot-sunxi-with-spl.bin of=${loop_device} bs=1024 seek=8 status=progress
fi

# create boot.cmd file
cat << 'EOF' > ${fs_dir}/boot/boot.cmd
setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p1 rootwait panic=10 rw rootfstype=ext4 net.ifnames=0
load mmc 0:1 $kernel_addr_r /boot/zImage
load mmc 0:1 $fdt_addr_r /boot/device_tree.dtb
bootz $kernel_addr_r - $fdt_addr_r
EOF

# Create u-boot boot script image
echo -e "${RED}${BOLD}Creating u-boot boot script ...${NORMAL}${NC}"
mkimage -A arm -T script -C none -d ${fs_dir}/boot/boot.cmd ${fs_dir}/boot/boot.scr

# mount loop-device 
mount -o loop ${loop_device}p1 /mnt
# sync file system files with mount dir
echo -e "${RED}${BOLD}Syncing file system...${NORMAL}${NC}"
rsync -HPavz -q ${fs_dir}/ /mnt
# unmount loop-device
umount /mnt
# desociate loop-device from image file
losetup -d ${loop_device}


echo -e "${RED}${BOLD}Image successfully saved in ${image_file}${NORMAL}${NC}"
