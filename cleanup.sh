#!/bin/bash

if [ $EUID -ne 0 ];then
	echo "This script must be run as root"
	exit 1
fi

set -eu pipefail

echo "Removing kali sources from sources.list"
sudo sed -i '$d' /etc/apt/sources.list
sudo sed -i '$d' /etc/apt/sources.list
echo "Removing kali keyring ..."
apt purge -y kali-archive-keyring debootstrap

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
