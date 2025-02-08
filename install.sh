#!/usr/bin/bash
set -e
# $1 = block device disk
# $2 = stage 3 file path
#
#

#
# Disks
#

fdisk "$1"

mkfs.fat -F 32 "$1"1
mkfs.ext4 -L "gentoo-root" "$1"2

mkdir --parents /mnt/gentoo
mount "$1"2 /mnt/gentoo
mkdir --parents /mnt/gentoo/efi

#
# Stage
#

cd /mnt/gentoo

chronyd -q

tar xpvf "$2" --xattrs-include='*.*' --numeric-owner -C "/mnt/gentoo"

echo -n '# Compiler flags to set for all languages\nCOMMON_FLAGS="-march=native -O2 -pipe"\n# Use the same settings for both variables\nCFLAGS="${COMMON_FLAGS}"\nCXXFLAGS="${COMMON_FLAGS}"\n' > /mnt/gentoo/etc/portage/make.conf

#
# Base
#

cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run 

chroot /mnt/gentoo /bin/bash

mount /dev/sda1 /efi

emerge-webrsync

emerge --sync

emerge --sync --quiet

eselect news read

eselect profile list

read -p "Enter correct list element: " listnameoption

eselect profile set "$listnameoption"

ln -sf ../usr/share/zoneinfo/Europe/Rome /etc/localtime

echo -n "en_US.UTF-8 UTF-8" > /etc/locale.gen

locale-gen

eselect locale list

read -p "Enter correct list element: " localeoption

eselect locale set "$localeoption"

env-update

#
# Kernel
#

emerge sys-kernel/linux-firmware

echo -n 'sys-apps/systemd boot\nsys-kernel/installkernel systemd-boot' > /etc/portage/package.use/systemd-boot

emerge --ask sys-apps/systemd sys-kernel/installkernel

echo "quiet splash" > /etc/kernel/cmdline

echo "sys-kernel/installkernel dracut" > /etc/portage/package.use/installkernel

emerge --ask sys-kernel/installkernel

emerge --ask sys-kernel/gentoo-kernel-bin

echo -n 'USE="dist-kernel"\n' >> /etc/portage/make.conf

emerge @module-rebuild

emerge --ask sys-kernel/gentoo-sources

eselect kernel list

read -p "Enter correct list element: " listkerneloption

eselect kernel set "$listkerneloption"

#
# System
#

blkid

echo '/dev/sda1 /efi vfat umask=0077 0 2\n/dev/sda2 / ext4 defaults,noatime 0 1' > /etc/fstab

read -p "Enter hostname: " hostameinput

echo "$hostameinput" > /etc/hostname

emerge net-misc/dhcpcd

systemctl enable dhcpcd

echo "127.0.0.1 $hostameinput.homenetwork $hostameinput localhost" > /etc/hosts

passwd

systemd-machine-id-setup

systemd-firstboot --prompt

systemctl preset-all --preset-mode=enable-only

systemctl preset-all

#
# Tools
#

emerge app-shells/bash-completion

systemctl enable systemd-timesyncd.service

emerge sys-fs/dosfstools

emerge net-misc/dhcpcd

#
# Bootloader
#

emerge sys-apps/systemd

bootctl install

bootctl list

read -p "Verifica se esiste l'entrata, esegui 'emerge --ask --config sys-kernel/gentoo-kernel-bin' e poi ricontrolla"

echo "Riavvia il pc"