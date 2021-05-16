#!/bin/sh

config() {
    lsblk
    read -p "drive (/dev/disk): " DRIVE
    HOSTNAME='lemon'
    USER='h31s'
    TIMEZONE='Europe/Madrid'
    KEYMAP='us'
}

prepare_disk() {
    echo "-------------------------- PREPARING DISK --------------------------"
    parted --script $DRIVE \
        mklabel gpt \
	mkpart primary ext4 512MiB 100% \
	mkpart EFI fat32 1MiB 512MiB \
	set 2 esp on
    cryptsetup luksFormat "$DRIVE"1
    cryptsetup luksOpen "$DRIVE"1 h31s
    mkfs.ext4 -L arch_os -O "^has_journal" /dev/mapper/h31s
    mkfs.fat -F 32 "$DRIVE"2
    mkdir -p /mnt
    mount /dev/mapper/h31s /mnt
    mkdir -p /mnt/boot
    mount "$DRIVE"2 /mnt/boot
    echo "-------------------------- DISK READY --------------------------"
}

chroot() {
    cp $0 /mnt/arch-install
    arch-chroot /mnt ./arch-install.sh chroot
}
    
configuracion() {
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    echo "KEYMAP=us" > /etc/vconsole.conf
    echo "$HOSTNAME" > /etc/hostname
    cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1       localhost
EOF
    systemctl enable NetworkManager
    grep -q "^Color" /etc/pacman.conf || sed -i "s/^#Color$/Color/" /etc/pacman.conf
    grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
}

usb_tweaks() {
    sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev block keyboard autodetect modconf filesystems fsck)/g' /etc/mkinitcpio.conf
    mkinitcpio -p linux
    sed -i 's/#Storage=auto/Storage=volatile/g' /etc/systemd/journald.conf
    sed -i 's/#SystemMaxUse=/SystemMaxUse=30M/g' /etc/systemd/journald.conf
}

install_paru() {
    cd /tmp
    rm -rf /tmp/paru
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg --noconfirm -si
    cd /
}

user() {
    useradd -m -G wheel -s /bin/zsh $USER
    passwd $USER
}

bootloader() {
}

set -ex

if [ "$1" == "chroot" ]
then
    configuracion
    usb_tweaks
    install_paru
    rm -f /mnt/arch-install
else
    config
    prepare_disk
    pacstrap /mnt linux linux-firmware base base-devel neovim networkmanager git zsh
    genfstab -U /mnt >> /mnt/etc/fstab
    chroot
fi
