#!/usr/bin/bash
set -e
# $1 = block device disk
# $2 = stage 3 file path

options=("disk" "stage" "base-setup" "base-chroot" "kernel" "system" "tools" "bootloader" "exit")

if [[ $UID != "0" ]]; then
    echo "usa 'sudo -i'"
    exit
fi

select menu in "${options[@]}";
do
    echo -e "\nyou picked $menu ($REPLY)"
    if [[ $menu == "disk" ]]; then
        # Disks - 1
        fdisk "$1"
        mkfs.fat -F 32 "$1"1
        mkfs.ext4 -L "gentoo-root" "$1"2
        mkdir --parents /mnt/gentoo
        mount "$1"2 /mnt/gentoo
        mkdir --parents /mnt/gentoo/efi
        cp "$(realpath $0)" /mnt/gentoo
    fi
    if [[ $menu == "stage" ]]; then
        # Stage - 2
        chronyd -q
        echo "$(realpath $2)"
        tar xpvf "$(realpath $2)" --xattrs-include='*.*' --numeric-owner -C "/mnt/gentoo"
        echo '# Compiler flags to set for all languages' >> /mnt/gentoo/etc/portage/make.conf
        echo 'COMMON_FLAGS="-march=native -O2 -pipe"' >> /mnt/gentoo/etc/portage/make.conf
        echo '# Use the same settings for both variables' >> /mnt/gentoo/etc/portage/make.conf
        echo 'CFLAGS="${COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf
        echo 'CXXFLAGS="${COMMON_FLAGS}"' >> /mnt/gentoo/etc/portage/make.conf
        echo 'ACCEPT_LICENSE="*"' >> /mnt/gentoo/etc/portage/make.conf
    fi
    if [[ $menu == "base-setup" ]]; then
        # Base - 3
        cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
        mount --types proc /proc /mnt/gentoo/proc
        mount --rbind /sys /mnt/gentoo/sys
        mount --make-rslave /mnt/gentoo/sys
        mount --rbind /dev /mnt/gentoo/dev
        mount --make-rslave /mnt/gentoo/dev
        mount --bind /run /mnt/gentoo/run
        mount --make-slave /mnt/gentoo/run
        chroot /mnt/gentoo
    fi
    if [[ $menu == "base-chroot" ]]; then
        # Base chroot - 4
        mount /dev/sda1 /efi
        emerge-webrsync
        emerge --sync
        eselect news read
        eselect profile list
        read -p "Enter correct list element: " listnameoption
        eselect profile set "$listnameoption"
        ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
        echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
        locale-gen
        eselect locale list
        read -p "Enter correct list element: " localeoption
        eselect locale set "$localeoption"
        env-update
    fi
    if [[ $menu == "kernel" ]]; then
        # Kernel - 5
        echo 'sys-apps/systemd boot' >> /etc/portage/package.use/systemd-boot
        echo 'sys-kernel/installkernel systemd-boot' >> /etc/portage/package.use/systemd-boot
        echo "sys-kernel/installkernel dracut" > /etc/portage/package.use/installkernel
        echo 'USE="dist-kernel"' >> /etc/portage/make.conf
        echo "quiet splash" > /etc/kernel/cmdline
        emerge sys-kernel/linux-firmware
        emerge sys-apps/systemd sys-kernel/installkernel
        emerge sys-kernel/gentoo-kernel
        emerge @module-rebuild
        emerge sys-kernel/gentoo-sources
        eselect kernel list
        read -p "Enter correct list element: " listkerneloption
        eselect kernel set "$listkerneloption"
    fi
    if [[ $menu == "system" ]]; then
        # System - 6
        blkid
        echo '/dev/sda1 /efi vfat umask=0077 0 2' >> /etc/fstab
        echo '/dev/sda2 / ext4 defaults,noatime 0 1' >> /etc/fstab
        read -p "Enter hostname: " hostameinput
        echo "$hostameinput" > /etc/hostname
        emerge net-misc/dhcpcd
        echo "127.0.0.1 $hostameinput.homenetwork $hostameinput localhost" > /etc/hosts
        echo "Metti la password di root"
        passwd
        systemd-machine-id-setup
        systemd-firstboot --prompt
        systemctl enable dhcpcd
        systemctl preset-all --preset-mode=enable-only
        systemctl preset-all
    fi
    if [[ $menu == "tools" ]]; then
        # Tools - 7
        emerge app-shells/bash-completion
        systemctl enable systemd-timesyncd.service
        emerge sys-fs/dosfstools
        emerge net-misc/dhcpcd
    fi
    if [[ $menu == "bootloader" ]]; then
        # Bootloader - 8
        emerge sys-apps/systemd
        bootctl install
        bootctl list
        echo "Verifica se esiste l'entrata, esegui 'emerge --ask --config sys-kernel/gentoo-kernel-bin' e poi ricontrolla"
        echo "esegui 'systemctl enable dhcpd.service --now' per internet"
        echo "Riavvia il pc"
    fi
    if [[ $menu == "exit" ]]; then
        exit
    fi
done
