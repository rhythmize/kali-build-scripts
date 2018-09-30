# kali-build-scripts
Kali linux build scripts for libretech-all-h3-cc h2+ DIY board

Usage
------
**Run all scripts with sudo**

1. sudo do_init.sh 
    > Install required packages and keyrings to build kali filesystem. Packages like debootstarp are required.
2. sudo create_image.sh
    > Actual script which creates kali filesystem on the host computer and finishes by created an .img file.
    This script uses `config_target.sh` to configure and install required tools and packages on target filesystem.
3. sudo cleanup.sh
    > Uninstalls all the packages, that won't be required now.
