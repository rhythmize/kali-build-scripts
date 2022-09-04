#!/bin/bash

with_linux_kernel_sources=false
with_linux_firmware_sources=false
with_uboot_sources=false

Usage() {
	echo "Install dependencies and fetch souces to build system image for the board"
	echo "usage: ./do_init.sh <options>"
	echo "options:"
	echo -e "\t--with-linux-kernel-sources		clone kernel sources from git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git (linux-4.18.y)"
	echo -e "\t--with-linux-firmware-sources		clone linux firmware souces from git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"
	echo -e "\t--with-uboot-sources			clone uboot from git://git.denx.de/u-boot.git"
	echo "NOTE: Script should run as root"
}

Init() {
	if [ $EUID -ne 0 ];then
		echo "This script must be run as root"
		exit 1
	fi

	basedir=$(pwd)

	set -euo pipefail

	if ! grep -q "deb http://http.kali.org/kali kali-rolling main" "/etc/apt/sources.list"; then
		echo "Adding kali sources to sources.list ..."
		echo "deb http://http.kali.org/kali kali-rolling main non-free contrib" >> /etc/apt/sources.list
		echo "deb-src http://http.kali.org/kali kali-rolling main non-free contrib" >> /etc/apt/sources.list
	fi

	echo "Adding kali archive gpg signatures ..."
	wget -q -O - https://archive.kali.org/archive-key.asc | apt-key add

	echo "Installing required packages ..."
	apt update || apt -y -f install
	apt install -y kali-archive-keyring debootstrap qemu-user-static systemd-container

	echo "Adding kali-rolling to debootstrap scripts ..."
	cd '/usr/share/debootstrap/scripts/'
	(echo "default_mirror http://http.kali.org/kali"; sed -e "s/debian-archive-keyring.gpg/kali-archive-keyring.gpg/g" sid) > kali
	ln -sf kali kali-rolling
	cd ${basedir}

	if $with_linux_kernel_sources; then
		# You can here change if you want some customized kernel
		echo "Cloning linux kernel 4.18..."
		git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git -b linux-4.18.y linux
	fi

	if $with_linux_firmware_sources; then
		# You can change if you want to use customized kernel firmware
		echo "Cloning linux kernel firmware ..."
		git clone git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git linux-firmware
	fi

	if $with_uboot_sources; then
		# You can change here if you want some customized bootloader
		echo "Cloning u-boot ..."
		git clone git://git.denx.de/u-boot.git u-boot
	fi
	echo "Init done ..."
}

for arg in "$@"; do
  case "$arg" in
    '--help')
		Usage
		exit;;
    '--with-linux-kernel-sources')
		with_linux_kernel_sources=true
		;;
    '--with-linux-firmware-sources')
		with_linux_firmware_sources=true
		;;
    '--with-uboot-sources')
		with_uboot_sources=true
		;;
  esac
done

Init
