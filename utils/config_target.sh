#!/bin/bash

set -euo pipefail
if [ $EUID -ne 0 ];then
	echo "This script must be run as root"
	exit 1
fi

BOLD=$(tput bold)
NORMAL=$(tput sgr0)
RED='\033[0;31m'
NC='\033[0m' # No Color

base="ssh console-common binutils locales git man-db lshw wpasupplicant"
core="kali-defaults e2fsprogs usbutils firmware-linux-free"
tools="aircrack-ng ethtool hydra libnfc-bin mfoc nmap passing-the-hash sqlmap winexe wireshark"

# Change root password
echo "root:toor" | chpasswd

# update sources.list to https
cat << EOF > /etc/apt/sources.list
deb http://http.kali.org/kali kali-rolling main non-free contrib
deb-src http://http.kali.org/kali kali-rolling main non-free contrib
EOF


# install linux packages
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

echo -e "${RED}${BOLD}[+] Installing base system packages ...${NORMAL}${NC}"
apt-get install -y ${base} || apt-get -y -f install

# ssh on boot
systemctl enable ssh
# root login over ssh
sed -i -e 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# kali specific packages
echo -e "${RED}${BOLD}[+] Installing core packages ...${NORMAL}${NC}"
apt install -y ${core} || apt-get -y -f install
echo -e "${RED}${BOLD}[+] Installing kali tools ...${NORMAL}${NC}"
apt install -y ${tools} || apt-get -y -f install

# cleanup
echo -e "${RED}${BOLD}[+] Cleaning Up ...${NORMAL}${NC}"
apt-get autoremove
apt-get autoclean
