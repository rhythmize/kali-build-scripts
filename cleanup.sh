#!/bin/bash

if [ $EUID -ne 0 ];then
	echo "This script must be run as root"
	exit 1
fi

set -euo pipefail

if grep -q "deb http://http.kali.org/kali kali-rolling main non-free contrib" "/etc/apt/sources.list"; then
	echo "Removing kali sources from sources.list"
	sudo sed -i '$d' /etc/apt/sources.list
	sudo sed -i '$d' /etc/apt/sources.list
fi
echo "Removing kali keyring ..."
apt purge -y kali-archive-keyring debootstrap qemu-user-static

echo "Cleaning Up ..."
apt -y autoremove
apt -y autoclean

# clear kernel directory
echo "Cleaning kernel directory"
rm -rf linux

# clear linux firmware directory
echo "Cleaning linux firmware directory"
rm -rf linux-firmware

# clear bootloader directory
echo "Cleaning u-boot directory"
rm -rf u-boot
