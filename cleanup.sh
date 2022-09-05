#!/bin/bash

if [ $EUID -ne 0 ];then
	echo "This script must be run as root"
	exit 1
fi

BOLD=$(tput bold)
NORMAL=$(tput sgr0)
RED='\033[0;31m'
NC='\033[0m' # No Color

set -euo pipefail

if grep -q "deb http://http.kali.org/kali kali-rolling main non-free contrib" "/etc/apt/sources.list"; then
	echo -e "${RED}${BOLD}[+] Removing kali sources from sources.list${NORMAL}${NC}"
	sudo sed -i '$d' /etc/apt/sources.list
	sudo sed -i '$d' /etc/apt/sources.list
fi
echo -e "${RED}${BOLD}[+] Removing kali keyring ...${NORMAL}${NC}"
apt purge -y kali-archive-keyring debootstrap qemu-user-static systemd-container u-boot-tools

echo -e "${RED}${BOLD}[+] Cleaning Up ...${NORMAL}${NC}"
apt -y autoremove
apt -y autoclean

# clear kernel directory
echo -e "${RED}${BOLD}[+] Cleaning kernel directory${NORMAL}${NC}"
rm -rf linux

# clear linux firmware directory
echo -e "${RED}${BOLD}[+] Cleaning linux firmware directory${NORMAL}${NC}"
rm -rf linux-firmware

# clear bootloader directory
echo -e "${RED}${BOLD}[+] Cleaning u-boot directory${NORMAL}${NC}"
rm -rf u-boot
