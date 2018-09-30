#!/bin/bash

if [ $EUID -ne 0 ];then
	echo "This script must be run as root"
	exit 1
fi

set -eu pipefail
if ! grep -q "deb http://http.kali.org/kali kali-rolling main non-free contrib" "/etc/apt/sources.list"; then
	echo "Adding kali sources to sources.list ..."
	echo "deb http://http.kali.org/kali kali-rolling main non-free contrib" >> /etc/apt/sources.list
	echo "deb-src http://http.kali.org/kali kali-rolling main non-free contrib" >> /etc/apt/sources.list
fi 

echo "Adding kali archive gpg signatures ..."
wget -q -O - https://archive.kali.org/archive-key.asc | apt-key add

echo "Installing kali archive keyrings and debootstrap ..."
apt update
apt install -y kali-archive-keyring debootstrap

echo "Adding kali-rolling to debootstrap scripts ..."
cd '/usr/share/debootstrap/scripts/'
(echo "default_mirror http://http.kali.org/kali"; sed -e "s/debian-archive-keyring.gpg/kali-archive-keyring.gpg/g" sid) > kali
ln -sf kali kali-rolling

# You can here change if you want some customized kernel
echo "Cloning linux kernel 4.18..."
git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git -b linux-4.18.y linux


# You can change if you want to use customized kernel firmware
echo "Cloning linux kernel firmware ..."
git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git linux-firmware

# You can change here if you want some customized bootloader
echo "Cloning u-boot ..."
git clone git://git.denx.de/u-boot.git u-boot

echo "Init done ..."
