#!/bin/sh

# CONFIGURATION
read -p "drive (/dev/disk): " DRIVE
read -p "host: " HOSTNAME
read -p "encrytion? (y/n): " ENCRYPTION
read -p "user: " USER_NAME
TIMEZONE='Europe/Madrid'
KEYMAP='us'

# Preparing the disk
echo "paritioning $DRIVE"
parted --script $DRIVE \
	mklabel gpt \
	mkpart "root partition" ext4 512MiB 100% \
	mkpart "EFI system partition" fat32 1MiB 512MiB \
	set 2 esp on
echo "formating $DRIVE paritions"
mkfs.ext4 "$DRIVE"1
mkfs.fat -F 32 "$DRIVE"2
echo "mounting $DRIVE partitions"
mkdir -p /mnt
mount "$DRIVE"1 /mnt
mkdir -p /mnt/boot
mount "$DRIVE"2 /mnt/boot

# Install
pacstrap /mnt linux linux-firmware base base-devel neovim networkmanager

# Configuring arch
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
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

# Usb tweaks

# Install Paru
cd /tmp || exit 1
rm -rf /tmp/paru
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg --noconfirm -si
cd /
